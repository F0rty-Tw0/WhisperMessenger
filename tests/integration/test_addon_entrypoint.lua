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
  local savedGetPlayerInfoByGUID = _G.GetPlayerInfoByGUID
  local savedUnitFullName = _G.UnitFullName
  local savedGetNormalizedRealmName = _G.GetNormalizedRealmName

  local createdFrames = {}
  local factory = FakeUI.NewFactory()

  _G.GetPlayerInfoByGUID = function(guid)
    if guid ~= "Player-3676-0ABCDEF0" then
      return nil
    end

    return "Priest", "PRIEST", "Human", "Human", 2, "Arthas", "Area52"
  end

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
  assert(eventFrame.events.ADDON_LOADED == true)
  assert(eventFrame.events.CHAT_MSG_WHISPER == nil)

  local Bootstrap = ns.Bootstrap
  eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "WhisperMessenger")

  local runtime = Bootstrap.runtime
  assert(runtime ~= nil, "expected bootstrap runtime after load")
  assert(runtime.localProfileId == "arthas-area52")
  assert(runtime.activeConversationKey == nil)
  assert(type(runtime.pendingOutgoing) == "table")
  assert(type(runtime.availabilityByGUID) == "table")
  assert(type(runtime.store) == "table")
  assert(type(runtime.queue) == "table")
  assert(runtime.store.conversations == runtime.accountState.conversations)

  assert(eventFrame.events.ADDON_LOADED == nil)
  assert(eventFrame.events.CHAT_MSG_WHISPER == true)
  assert(eventFrame.events.CHAT_MSG_WHISPER_INFORM == true)
  assert(eventFrame.events.CHAT_MSG_AFK == true)
  assert(eventFrame.events.CHAT_MSG_DND == true)
  assert(eventFrame.events.CAN_LOCAL_WHISPER_TARGET_RESPONSE == true)

  eventFrame.scripts.OnEvent(
    eventFrame,
    "CHAT_MSG_WHISPER",
    "hi there",
    "Arthas-Area52",
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    101,
    "Player-3676-0ABCDEF0"
  )

  local conversation = runtime.store.conversations["wow::WOW::arthas-area52"]
  assert(conversation ~= nil, "expected whisper event to reach runtime store")
  assert(#conversation.messages == 1)
  assert(conversation.messages[1].text == "hi there")
  assert(runtime.window.contacts.rows[1].item.conversationKey == "wow::WOW::arthas-area52")
  assert(conversation.className == "Priest")
  assert(conversation.classTag == "PRIEST")
  assert(conversation.raceName == "Human")
  assert(conversation.raceTag == "Human")
  assert(conversation.factionName == "Alliance")
  assert(runtime.window.contacts.rows[1].item.className == "Priest")
  assert(runtime.window.contacts.rows[1].item.factionName == "Alliance")

  _G.SlashCmdList.WHISPERMESSENGER()
  assert(runtime.window.frame.shown == true)
  runtime.window.contacts.rows[1].scripts.OnClick()
  assert(runtime.activeConversationKey == "wow::WOW::arthas-area52")
  assert(runtime.characterState.activeConversationKey == "wow::WOW::arthas-area52")
  assert(conversation.unreadCount == 0)
  assert(runtime.window.conversation.header.text == "Arthas-Area52")

  eventFrame.scripts.OnEvent(
    eventFrame,
    "CHAT_MSG_WHISPER",
    "still there",
    "Arthas-Area52",
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    102,
    "Player-3676-0ABCDEF0"
  )
  assert(#conversation.messages == 2)
  assert(conversation.unreadCount == 0)
  assert(runtime.window.conversation.transcript.lines[2] == "still there")

  runtime.window.closeButton.scripts.OnClick(runtime.window.closeButton)
  assert(runtime.window.frame.shown == false)

  eventFrame.scripts.OnEvent(
    eventFrame,
    "CHAT_MSG_WHISPER",
    "ping again",
    "Arthas-Area52",
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    103,
    "Player-3676-0ABCDEF0"
  )
  assert(#conversation.messages == 3)
  assert(conversation.unreadCount == 1)
  _G.require = savedRequire
  _G.CreateFrame = savedCreateFrame
  _G.SlashCmdList = savedSlashCmdList
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
  _G.GetPlayerInfoByGUID = savedGetPlayerInfoByGUID
  _G.UnitFullName = savedUnitFullName
  _G.GetNormalizedRealmName = savedGetNormalizedRealmName
end
