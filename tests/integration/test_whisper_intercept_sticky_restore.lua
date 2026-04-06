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
  local savedGlobals = {
    require = require,
    CreateFrame = _G.CreateFrame,
    C_Timer = _G.C_Timer,
    ChatEdit_DeactivateChat = _G.ChatEdit_DeactivateChat,
    NUM_CHAT_WINDOWS = _G.NUM_CHAT_WINDOWS,
    ChatFrame1EditBox = _G.ChatFrame1EditBox,
    UIParent = _G.UIParent,
    SlashCmdList = _G.SlashCmdList,
    SLASH_WHISPERMESSENGER1 = _G.SLASH_WHISPERMESSENGER1,
    SLASH_WHISPERMESSENGER2 = _G.SLASH_WHISPERMESSENGER2,
    UnitFullName = _G.UnitFullName,
    GetNormalizedRealmName = _G.GetNormalizedRealmName,
  }

  local createdFrames = {}
  local timerCallbacks = {}
  local deactivated = {}
  local factory = FakeUI.NewFactory()

  local function findCreatedFrameWithScript(scriptName)
    for _, frame in ipairs(createdFrames) do
      if frame.scripts and frame.scripts[scriptName] then
        return frame
      end
    end
    return nil
  end

  local function makeInterceptedEditBox(name, attributeState, directState, text)
    local editBox = factory.CreateFrame("EditBox", name, _G.UIParent)
    local state = {}
    for key, value in pairs(attributeState) do
      state[key] = value
    end

    function editBox:SetAttribute(key, value)
      state[key] = value
    end

    function editBox:GetAttribute(key)
      return state[key]
    end

    editBox.chatType = directState.chatType
    editBox.stickyType = directState.stickyType
    editBox.tellTarget = directState.tellTarget
    editBox:SetText(text)
    editBox:SetFocus()
    _G.ChatFrame1EditBox = editBox

    return editBox
  end

  local function assertInterceptedState(caseLabel, runtime, editBox, expected)
    local conversationKey = runtime.activeConversationKey
    local conversation = conversationKey and runtime.store.conversations[conversationKey] or nil

    assert(conversation ~= nil, "expected " .. caseLabel .. " whisper interception to select a conversation")
    assert(
      conversation.displayName == expected.displayName,
      "expected " .. caseLabel .. " whisper interception to target " .. expected.displayName
    )
    assert(
      runtime.window.conversation.header.text == expected.displayName,
      "expected messenger header to update for " .. caseLabel .. " whisper target"
    )
    assert(
      runtime.window.composer.input:GetText() == expected.draftText,
      "expected " .. caseLabel .. " draft to transfer into composer"
    )
    assert(
      #deactivated == expected.deactivateIndex and deactivated[expected.deactivateIndex] == editBox,
      "expected " .. caseLabel .. " whisper edit box to close"
    )
    -- chatType/tellTarget are restored via attributes only (not direct properties)
    -- to avoid tainting secure state on subsequent whisper calls.
    assert(
      editBox:GetAttribute("chatType") == expected.stickyType,
      "expected " .. caseLabel .. " secure chatType restored to sticky " .. expected.stickyType
    )
    assert(editBox:GetAttribute("tellTarget") == nil, "expected " .. caseLabel .. " secure tellTarget cleared")
    assert(editBox:GetText() == "", "expected " .. caseLabel .. " Blizzard edit box text to be cleared")
    assert(editBox.shown == false, "expected " .. caseLabel .. " whisper edit box to hide")
    assert(editBox:HasFocus() == false, "expected " .. caseLabel .. " whisper edit box to lose focus")
  end

  _G.require = nil
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.SlashCmdList = {}
  _G.SLASH_WHISPERMESSENGER1 = nil
  _G.SLASH_WHISPERMESSENGER2 = nil
  _G.NUM_CHAT_WINDOWS = 1
  rawset(_G, "UnitFullName", function(unit)
    assert(unit == "player")
    return "Arthas", "Area52"
  end)
  rawset(_G, "GetNormalizedRealmName", function()
    return "Area52"
  end)
  _G.C_Timer = {
    After = function(delaySeconds, callback)
      timerCallbacks[#timerCallbacks + 1] = {
        delaySeconds = delaySeconds,
        callback = callback,
      }
    end,
  }
  rawset(_G, "ChatEdit_DeactivateChat", function(editBox)
    deactivated[#deactivated + 1] = editBox
    if editBox.ClearFocus then
      editBox:ClearFocus()
    end
    if editBox.Hide then
      editBox:Hide()
    end
  end)
  rawset(_G, "CreateFrame", function(frameType, name, parent, template)
    local frame = factory.CreateFrame(frameType, name, parent, template)
    createdFrames[#createdFrames + 1] = frame

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

  local eventFrame = findCreatedFrameWithScript("OnEvent")
  assert(eventFrame ~= nil, "expected addon load event frame")
  eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "WhisperMessenger")

  local runtime = ns.Bootstrap.runtime
  assert(runtime ~= nil, "expected runtime after addon load")
  runtime.accountState.settings.autoOpenIncoming = true
  runtime.accountState.settings.autoOpenOutgoing = true
  assert(#timerCallbacks == 1, "expected deferred poll install after addon load")

  timerCallbacks[1].callback()

  local pollFrame = findCreatedFrameWithScript("OnUpdate")
  assert(pollFrame ~= nil, "expected whisper interception poll frame")

  local directFieldEditBox = makeInterceptedEditBox("ChatFrame1EditBox", {
    chatType = "WHISPER",
    stickyType = "PARTY",
    tellTarget = "Jaina",
  }, {
    chatType = "WHISPER",
    stickyType = "PARTY",
    tellTarget = "Jaina",
  }, "Need a summon")

  pollFrame.scripts.OnUpdate(pollFrame)

  assert(runtime.window ~= nil, "expected whisper interception to ensure the messenger window")
  assert(runtime.window.frame.shown == true, "expected whisper interception to show the messenger window")
  assertInterceptedState("direct-field", runtime, directFieldEditBox, {
    displayName = "Jaina",
    draftText = "Need a summon",
    stickyType = "PARTY",
    deactivateIndex = 1,
  })

  local attributeBackedEditBox = makeInterceptedEditBox("ChatFrame1EditBox", {
    chatType = "WHISPER",
    stickyType = "SAY",
    tellTarget = "Uther",
  }, {
    chatType = "",
    stickyType = "",
    tellTarget = "",
  }, "attribute backed whisper")

  pollFrame.scripts.OnUpdate(pollFrame)

  assertInterceptedState("attribute-backed", runtime, attributeBackedEditBox, {
    displayName = "Uther",
    draftText = "attribute backed whisper",
    stickyType = "SAY",
    deactivateIndex = 2,
  })

  _G.require = savedGlobals.require
  rawset(_G, "CreateFrame", savedGlobals.CreateFrame)
  _G.C_Timer = savedGlobals.C_Timer
  rawset(_G, "ChatEdit_DeactivateChat", savedGlobals.ChatEdit_DeactivateChat)
  _G.NUM_CHAT_WINDOWS = savedGlobals.NUM_CHAT_WINDOWS
  _G.ChatFrame1EditBox = savedGlobals.ChatFrame1EditBox
  _G.UIParent = savedGlobals.UIParent
  _G.SlashCmdList = savedGlobals.SlashCmdList
  _G.SLASH_WHISPERMESSENGER1 = savedGlobals.SLASH_WHISPERMESSENGER1
  _G.SLASH_WHISPERMESSENGER2 = savedGlobals.SLASH_WHISPERMESSENGER2
  rawset(_G, "UnitFullName", savedGlobals.UnitFullName)
  rawset(_G, "GetNormalizedRealmName", savedGlobals.GetNormalizedRealmName)
end
