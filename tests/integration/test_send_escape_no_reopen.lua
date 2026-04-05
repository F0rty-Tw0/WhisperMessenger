local FakeUI = require("tests.helpers.fake_ui")

local function loadAddonFromToc(addonName, ns)
  for line in io.lines("WhisperMessenger.toc") do
    if line ~= "" and string.sub(line, 1, 2) ~= "##" and not string.match(line, "%.xml$") then
      local chunk = assert(loadfile(line))
      chunk(addonName, ns)
    end
  end
end

return function()
  local savedCreateFrame = _G.CreateFrame
  local savedSlashCmdList = _G.SlashCmdList
  local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
  local savedSlash2 = _G.SLASH_WHISPERMESSENGER2
  local savedChatInfo = _G.C_ChatInfo
  local savedUnitFullName = _G.UnitFullName
  local savedGetNormalizedRealmName = _G.GetNormalizedRealmName
  local savedInCombatLockdown = _G.InCombatLockdown

  local createdFrames = {}
  local sendCalls = {}
  local factory = FakeUI.NewFactory()

  rawset(_G, "UnitFullName", function(unit)
    assert(unit == "player")
    return "Arthas", "Area52"
  end)
  rawset(_G, "GetNormalizedRealmName", function()
    return "Area52"
  end)
  rawset(_G, "InCombatLockdown", function()
    return false
  end)

  _G.SlashCmdList = {}
  _G.SLASH_WHISPERMESSENGER1 = nil
  _G.SLASH_WHISPERMESSENGER2 = nil
  _G.C_ChatInfo = {
    SendChatMessage = function(message, chatType, _, target)
      table.insert(sendCalls, {
        message = message,
        chatType = chatType,
        target = target,
      })
    end,
  }

  rawset(_G, "CreateFrame", function(frameType, name, parent)
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
  end)

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
  runtime.accountState.settings.autoOpenWindow = true

  local function dispatchWhisper(eventName, text, playerName, lineID, guid)
    eventFrame.scripts.OnEvent(eventFrame, eventName, text, playerName, "", "", "", "", "", "", "", "", lineID, guid)
  end

  dispatchWhisper("CHAT_MSG_WHISPER", "Need help?", "Arthas-Area52", 101, "Player-3676-0ABCDEF0")

  runtime.toggle()
  assert(runtime.window ~= nil, "expected window after toggle")
  runtime.window.contacts.rows[1].scripts.OnClick()

  runtime.window.composer.input:SetText("hello")
  runtime.window.composer.input.scripts.OnEnterPressed(runtime.window.composer.input)
  assert(#sendCalls == 1, "expected one sent message")

  runtime.window.composer.input.scripts.OnEscapePressed(runtime.window.composer.input)
  assert(runtime.window.frame.shown == false, "window should close on escape")

  -- Outgoing event arrives later with short player name (common WoW behavior).
  dispatchWhisper("CHAT_MSG_WHISPER_INFORM", "hello", "Arthas", 102, "Player-3676-0ABCDEF0")

  assert(runtime.window.frame.shown == false, "window should not reopen for tracked pending send inform")

  _G.CreateFrame = savedCreateFrame
  _G.SlashCmdList = savedSlashCmdList
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
  _G.C_ChatInfo = savedChatInfo
  rawset(_G, "UnitFullName", savedUnitFullName)
  rawset(_G, "GetNormalizedRealmName", savedGetNormalizedRealmName)
  rawset(_G, "InCombatLockdown", savedInCombatLockdown)
end
