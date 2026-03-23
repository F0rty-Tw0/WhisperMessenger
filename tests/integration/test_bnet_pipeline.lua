local FakeUI = require("tests.helpers.fake_ui")

local function loadAddonFromToc(addonName, ns)
  for line in io.lines("WhisperMessenger.toc") do
    if line ~= "" and string.sub(line, 1, 2) ~= "##" then
      local chunk = assert(loadfile(line))
      chunk(addonName, ns)
    end
  end
end

return function()
  local savedRequire = require
  local savedCreateFrame = _G.CreateFrame
  local savedSlashCmdList = _G.SlashCmdList
  local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
  local savedSlash2 = _G.SLASH_WHISPERMESSENGER2
  local savedChatInfo = _G.C_ChatInfo
  local savedBattleNet = _G.C_BattleNet
  local savedUnitFullName = _G.UnitFullName
  local savedGetNormalizedRealmName = _G.GetNormalizedRealmName

  local createdFrames = {}
  local sendCalls = {}
  local factory = FakeUI.NewFactory()

  _G.UnitFullName = function(unit)
    assert(unit == "player")
    return "Arthas", "Area52"
  end

  _G.GetNormalizedRealmName = function()
    return "Area52"
  end

  _G.require = nil
  _G.SlashCmdList = {}
  _G.SLASH_WHISPERMESSENGER1 = nil
  _G.SLASH_WHISPERMESSENGER2 = nil
  _G.C_ChatInfo = {
    SendChatMessage = function(message, chatType, _, target)
      table.insert(sendCalls, {
        message = message,
        chatType = chatType,
        target = target,
        transport = "WOW",
      })
    end,
  }
  _G.C_BattleNet = {
    SendWhisper = function(bnetAccountID, text)
      table.insert(sendCalls, {
        bnetAccountID = bnetAccountID,
        text = text,
        transport = "BN",
      })
      return true
    end,
    GetAccountInfoByID = function(bnetAccountID)
      if bnetAccountID ~= 99 then
        return nil
      end

      return {
        bnetAccountID = 99,
        accountName = "Jaina",
        battleTag = "Jaina#1234",
        gameAccountInfo = {
          characterName = "Jaina",
          realmName = "Proudmoore",
          playerGuid = "Player-60-0ABCDE123",
          className = "Mage",
          raceName = "Human",
          factionName = "Alliance",
        },
      }
    end,
  }
  _G.CreateFrame = function(frameType, name, parent)
    local frame = factory.CreateFrame(frameType, name, parent)
    table.insert(createdFrames, frame)

    function frame:RegisterEvent(eventName)
      self.events = self.events or {}
      self.events[eventName] = true
    end

    function frame:UnregisterEvent(eventName)
      if self.events then
        self.events[eventName] = nil
      end
    end

    return frame
  end

  local ns = {}
  loadAddonFromToc("WhisperMessenger", ns)

  local eventFrame
  for _, frame in ipairs(createdFrames) do
    if frame.scripts and frame.scripts.OnEvent then
      eventFrame = frame
      break
    end
  end

  assert(eventFrame ~= nil, "expected addon load event frame")

  eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "WhisperMessenger")

  local runtime = ns.Bootstrap.runtime
  assert(eventFrame.events.CHAT_MSG_BN_WHISPER == true)
  assert(eventFrame.events.CHAT_MSG_BN_WHISPER_INFORM == true)
  assert(eventFrame.events.CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE == true)

  eventFrame.scripts.OnEvent(
    eventFrame,
    "CHAT_MSG_BN_WHISPER",
    "hello from bn",
    "|Kq1|k",
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    301,
    nil,
    99,
    false,
    false,
    false,
    false
  )

  local conversationKey = "bnet::BN::jaina#1234"
  local conversation = runtime.store.conversations[conversationKey]
  assert(conversation ~= nil, "expected bn whisper conversation to be created")
  assert(conversation.channel == "BN")
  assert(conversation.displayName == "Jaina#1234")
  assert(conversation.bnetAccountID == 99)
  assert(conversation.gameAccountName == "Jaina-Proudmoore")
  assert(conversation.className == "Mage")
  assert(conversation.raceName == "Human")
  assert(conversation.factionName == "Alliance")

  -- Window is lazy — toggle to create it
  _G.SlashCmdList.WHISPERMESSENGER()
  assert(runtime.window ~= nil, "expected window after slash toggle")
  assert(runtime.window.contacts.rows[1].item.conversationKey == conversationKey)
  assert(runtime.window.contacts.rows[1].item.className == "Mage")
  assert(runtime.window.contacts.rows[1].item.factionName == "Alliance")
  runtime.window.contacts.rows[1].scripts.OnClick()
  assert(runtime.activeConversationKey == conversationKey)
  assert(runtime.window.conversation.header.text == "Jaina#1234")

  runtime.window.composer.input:SetText("reply over bn")
  runtime.window.composer.sendButton.scripts.OnClick()

  assert(sendCalls[1].transport == "BN")
  assert(sendCalls[1].bnetAccountID == 99)
  assert(sendCalls[1].text == "reply over bn")

  eventFrame.scripts.OnEvent(
    eventFrame,
    "CHAT_MSG_BN_WHISPER_INFORM",
    "reply over bn",
    "|Kq1|k",
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    302,
    nil,
    99,
    false,
    false,
    false,
    false
  )
  assert(#conversation.messages == 2)
  assert(conversation.messages[2].direction == "out")

  eventFrame.scripts.OnEvent(
    eventFrame,
    "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE",
    "Friend is offline",
    "|Kq1|k",
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    303,
    nil,
    99,
    false,
    false,
    false,
    false
  )
  assert(#conversation.messages == 3)
  assert(conversation.messages[3].kind == "system")

  _G.require = savedRequire
  _G.CreateFrame = savedCreateFrame
  _G.SlashCmdList = savedSlashCmdList
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
  _G.C_ChatInfo = savedChatInfo
  _G.C_BattleNet = savedBattleNet
  _G.UnitFullName = savedUnitFullName
  _G.GetNormalizedRealmName = savedGetNormalizedRealmName
end
