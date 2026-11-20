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

-- Runs fn(env) on the given flavor with the fake gamepad UI installed;
-- withoutApi: true on a client that has no gamepad UI, "partial" on one
-- that has only part of it.
local function onFlavor(isRetail, isForever, fn, withoutApi)
  local env = FakeGamepad.New()
  env.install(withoutApi)
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

  -- test_grips_are_ignored_and_chat_bubbles_reachable
  onFlavor(false, true, function(env)
    local window = build()
    assert(ignored(env, window.resizeGrip), "window resize grip")
    assert(ignored(env, window.contactsResizeHandle), "contacts resize handle")
    assert(not ignored(env, window.conversation.transcript.content), "chat bubbles are stops")
    assert(type(window.conversation.transcript.onNavTargetsChanged) == "function", "messages tagged as they render")
  end)

  -- Retail, Forever, Classic: isRetail, isForever of each flavor stub.
  for _, flavor in ipairs({ { true, false }, { true, true }, { false, false } }) do
    -- test_client_without_the_api_touches_no_gamepad_api
    onFlavor(flavor[1], flavor[2], function(env)
      local window = build()
      window.frame:Show()
      window.setOptionsVisible(true)
      assert(#env.calls == 0 and window.frame.SmartNavigationCloseHandler == nil, "no gamepad UI: unchanged")
    end, true)

    -- test_client_with_a_partial_api_builds_and_touches_no_gamepad_api
    onFlavor(flavor[1], flavor[2], function(env)
      local window = build()
      window.frame:Show()
      window.setOptionsVisible(true)
      assert(#env.calls == 0 and window.frame.SmartNavigationCloseHandler == nil, "part of the gamepad UI: unchanged")
    end, "partial")

    -- test_client_with_the_api_registers_on_any_flavor
    onFlavor(flavor[1], flavor[2], function(env)
      local window = build()
      window.frame:Show()
      window.setOptionsVisible(true)
      assert(env.count("FrameShown") == 1 and type(window.frame.SmartNavigationCloseHandler) == "function", "the API alone turns it on")
      assert(env.scrollFrameFor(window.frame) ~= window.conversation.transcript.scrollFrame, "the settings walk is on too")
    end)

    -- test_pad_hint_follows_the_cursor_in_the_built_window
    onFlavor(flavor[1], flavor[2], function()
      local savedInputUtil = rawget(_G, "InputUtil")
      rawset(_G, "InputUtil", {
        IsGamepadUIEnabled = function()
          return true
        end,
      })
      local ok, err = pcall(function()
        local window = build()
        local hint = window.composer.padHint
        assert(hint ~= nil, "the built window has the pad hint")
        window.composer.input:SetFocus()
        assert(hint.frame:IsShown() == true, "cursor in the box shows the hint")
        window.composer.input:ClearFocus()
        assert(hint.frame:IsShown() == false, "cursor out of the box hides it")
      end)
      rawset(_G, "InputUtil", savedInputUtil)
      assert(ok, err)
    end)

    -- test_built_window_puts_the_a_handler_on_the_message_box
    onFlavor(flavor[1], flavor[2], function()
      local window = build()
      local scroll = window.composer.scroll
      assert(type(scroll.OnSmartNavClick) == "function", "the built window sets the A handler on the message box")
      scroll.OnSmartNavClick(scroll)
      assert(window.composer.input:HasFocus() == true, "A puts the cursor in the box")
    end)
  end

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

  -- test_b_closes_the_emoji_picker_then_the_next_layer
  onFlavor(false, true, function(env)
    local window = build()
    window.frame:Show()
    env.flush()
    local picker = window.composer.emojiPicker
    local before = env.count("RefreshButtonGroups")
    -- open() refuses while the composer is disabled (no chat selected); the frame is what B and the re-scan see.
    picker.frame:Show()
    env.flush()
    local afterOpen = env.count("RefreshButtonGroups")
    assert(afterOpen > before, "opening the picker re-scans: its buttons are reachable")
    local close = window.frame.SmartNavigationCloseHandler
    assert(close(window.frame) == true and not picker.frame:IsShown() and window.frame:IsShown(), "B closes the picker only")
    env.flush()
    assert(env.count("RefreshButtonGroups") > afterOpen, "closing re-scans too")
    assert(close(window.frame) == true and not window.frame:IsShown(), "next B goes to the next layer: the window")
  end)

  -- test_b_closes_the_quick_reply_picker
  onFlavor(false, true, function(env)
    local window = build()
    window.frame:Show()
    local picker = window.composer.quickReplyPicker
    picker.frame:Show()
    env.flush()
    local afterOpen = env.count("RefreshButtonGroups")
    assert(window.frame.SmartNavigationCloseHandler(window.frame) == true and not picker.frame:IsShown() and window.frame:IsShown(), "B closes it")
    env.flush()
    assert(env.count("RefreshButtonGroups") > afterOpen, "closing re-scans")
  end)

  -- test_emoji_button_toggle_rescans
  onFlavor(false, true, function(env)
    local window = build()
    window.frame:Show()
    env.flush()
    local before = env.count("RefreshButtonGroups")
    window.composer.setEmojiButtonShown(false)
    env.flush()
    assert(env.count("RefreshButtonGroups") > before, "hiding the emoji button re-scans")
  end)
end
