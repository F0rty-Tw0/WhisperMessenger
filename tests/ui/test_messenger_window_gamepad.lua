local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local Flavor = require("tests.helpers.flavor")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")

-- Like the live client, SetScript drops the hooks HookScript added before it.
local function withLiveSetScript(factory)
  local create = factory.CreateFrame
  factory.CreateFrame = function(...)
    local frame = create(...)
    local setScript = frame.SetScript
    frame.SetScript = function(self, eventName, handler)
      if self._hookScripts then
        self._hookScripts[eventName] = nil
      end
      return setScript(self, eventName, handler)
    end
    return frame
  end
  return factory
end

local function build()
  local factory = withLiveSetScript(FakeUI.NewFactory())
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1280, 720)
  local window = MessengerWindow.Create(factory, {})
  _G.UIParent = savedUIParent
  return window
end

-- Runs fn(env) on the given flavor with the fake gamepad UI installed.
local function onFlavor(isRetail, isForever, fn)
  local env = FakeGamepad.New()
  env.install()
  local ok, err = pcall(Flavor.With, isRetail, isForever, function()
    fn(env)
  end)
  env.uninstall()
  assert(ok, err)
end

local function ignored(env, widget)
  for _, c in ipairs(env.calls) do
    if c.name == "MarkFrameIgnored" and c.args[1] == widget then
      return true
    end
  end
  return false
end

return function()
  -- test_forever_window_registers_on_show
  onFlavor(false, true, function(env)
    local window = build()
    window.frame:Show()
    assert(env.count("FrameShown") == 1, "show registers with the gamepad UI")
  end)

  -- test_b_closes_settings_then_the_window
  onFlavor(false, true, function(env)
    local window = build()
    window.frame:Show()
    window.setOptionsVisible(true)
    local close = window.frame.SmartNavigationCloseHandler
    assert(close(window.frame) == true and not window.optionsPanel:IsShown() and window.frame:IsShown(), "B closes settings")
    assert(close(window.frame) == true and not window.frame:IsShown(), "B again closes the window")
    assert(env.count("FrameHidden") == 1, "closing unregisters")
  end)

  -- test_contacts_and_settings_changes_rescan
  onFlavor(false, true, function(env)
    local window = build()
    window.frame:Show()
    local before = env.count("RefreshButtonGroups")
    window.refreshContacts({})
    local afterContacts = env.count("RefreshButtonGroups")
    assert(afterContacts > before, "contacts refresh re-scans")
    window.setOptionsVisible(true)
    assert(env.count("RefreshButtonGroups") > afterContacts, "settings toggle re-scans")
  end)

  -- test_right_stick_scroll_rerenders_the_chat
  onFlavor(false, true, function(env)
    local window = build()
    window.frame:Show()
    local transcript = window.conversation.transcript
    assert(env.scrollFrameFor(window.frame) == transcript.scrollFrame, "right stick scrolls the chat")
    local saved, renders = TranscriptView.RefreshViewport, 0
    TranscriptView.RefreshViewport = function(...)
      renders = renders + 1
      return saved(...)
    end
    transcript.content:SetHeight(5000)
    local ok, err = pcall(function()
      transcript.scrollFrame:SetVerticalScroll(40)
    end)
    TranscriptView.RefreshViewport = saved
    assert(ok, err)
    assert(renders >= 1, "a raw SetVerticalScroll still re-renders the virtualized chat")
  end)

  -- test_grips_and_chat_bubbles_are_ignored
  onFlavor(false, true, function(env)
    local window = build()
    assert(ignored(env, window.resizeGrip), "window resize grip")
    assert(ignored(env, window.contactsResizeHandle), "contacts resize handle")
    assert(ignored(env, window.conversation.transcript.content), "chat bubbles")
  end)

  -- test_retail_touches_no_gamepad_api
  onFlavor(true, false, function(env)
    local window = build()
    window.frame:Show()
    window.setOptionsVisible(true)
    assert(#env.calls == 0 and window.frame.SmartNavigationCloseHandler == nil, "Retail unchanged")
  end)

  -- test_settings_panes_take_the_right_stick_and_rescan_on_tab_select
  onFlavor(false, true, function(env)
    local window = build()
    window.frame:Show()
    window.setOptionsVisible(true)
    local pageScroll = window.settingsPanels[1]:GetParent():GetParent()
    assert(env.scrollFrameFor(window.frame) == pageScroll, "right stick scrolls the settings page")
    env.flush()
    local before = env.count("RefreshButtonGroups")
    window.appearanceTab:GetScript("OnClick")(window.appearanceTab)
    env.flush()
    assert(env.count("RefreshButtonGroups") > before, "tab select re-scans")
    window.setOptionsVisible(false)
    assert(env.scrollFrameFor(window.frame) == window.conversation.transcript.scrollFrame, "chat again after settings close")
  end)
end
