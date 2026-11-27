-- The composer runtime builds the composer and holds back its focus on a quiet show.
local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local Flavor = require("tests.helpers.flavor")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local BottomBanner = require("WhisperMessenger.UI.ConversationPane.BottomBanner")
local Theme = require("WhisperMessenger.UI.Theme")
local ComposerRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ComposerRuntime")

-- conversation: the pane the runtime is wired to (a plain table by default).
local function build(settingsConfig, onNavTargetsChanged, windowOptions, factory, conversation)
  factory = factory or FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)
  local composerPane = factory.CreateFrame("Frame", nil, frame)
  composerPane:SetSize(400, 80)
  local calls = {}
  conversation = conversation or { tag = "conversation" }
  local runtime = ComposerRuntime.Create(factory, {
    frame = frame,
    layout = { composerPane = composerPane },
    settingsConfig = settingsConfig or {},
    windowOptions = windowOptions or {},
    conversation = conversation,
    messageActions = {
      bind = function(boundConversation, boundComposer)
        calls.bound = { boundConversation, boundComposer }
      end,
    },
    settingsRuntime = {
      setThemeTargets = function(themedConversation, themedComposer)
        calls.themed = { themedConversation, themedComposer }
      end,
    },
    closeWindow = function() end,
    refreshContacts = function() end,
    onNavTargetsChanged = onNavTargetsChanged,
  })
  return runtime, frame, calls, conversation
end

return function()
  -- test_quiet_show_holds_composer_focus_while_the_window_shows
  do
    local runtime, frame = build()
    local heldDuringShow = nil
    frame:SetScript("OnShow", function()
      heldDuringShow = runtime.isComposerFocusHeld()
    end)
    runtime.showWithoutComposerFocus()
    assert(frame:IsShown(), "window shown")
    assert(heldDuringShow == true, "focus held while OnShow runs")
  end

  -- test_quiet_show_releases_the_hold_afterwards
  do
    local runtime = build()
    runtime.showWithoutComposerFocus()
    assert(runtime.isComposerFocusHeld() == false, "hold released after the show")
  end

  -- test_failed_quiet_show_releases_the_hold_and_rethrows
  do
    local runtime, frame = build()
    rawset(frame, "Show", function()
      error("show failed", 0)
    end)
    local ok, err = pcall(runtime.showWithoutComposerFocus)
    assert(ok == false and err == "show failed", "show error passed through, got " .. tostring(err))
    assert(runtime.isComposerFocusHeld() == false, "hold released after the failed show")
  end

  -- test_theme_and_message_actions_target_the_built_composer
  do
    local runtime, _, calls, conversation = build()
    assert(runtime.composer ~= nil, "composer built")
    assert(calls.themed[1] == conversation and calls.themed[2] == runtime.composer, "theme targets the composer")
    assert(calls.bound[1] == conversation and calls.bound[2] == runtime.composer, "message actions bound to the composer")
  end

  -- test_saved_off_builds_without_the_emoji_button
  do
    local runtime = build({ showEmojiButton = false })
    assert(not runtime.composer.emojiButton:IsShown(), "a saved off builds without the emoji button")
  end

  -- test_emoji_toggle_tells_the_nav
  do
    local count = 0
    local runtime = build({}, function()
      count = count + 1
    end)
    runtime.composer.setEmojiButtonShown(false)
    assert(count == 1, "hiding the emoji button tells the nav once, got " .. count)
  end

  -- test_composer_recalls_from_the_window_history
  do
    local runtime = build(nil, nil, {
      getSentHistory = function()
        return { "hello" }
      end,
    })
    local input = runtime.composer.input
    input:SetText("")
    input.scripts.OnKeyDown(input, "UP")
    assert(input:GetText() == "hello", "Up recalls from the window's history, got " .. tostring(input:GetText()))
  end

  -- A real conversation pane and a composer with the controller hint.
  local function buildWithPane(beforeRuntime)
    local factory = FakeUI.NewFactory({ wrap = true })
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(600, 400)
    local pane = ConversationPane.Create(factory, parent, { displayName = "Arthas" }, { messages = {} })
    pane.activeStatusBanner.GetStringHeight = function()
      return 12
    end
    if beforeRuntime then
      beforeRuntime(pane)
    end
    local runtime = build(nil, nil, nil, factory, pane)
    return runtime, pane
  end

  -- The strip's base (the conversation pane's bottom edge) sits a divider
  -- above the composer, whose box starts a gutter below its top.
  local STRIP_LIFT = BottomBanner.HEIGHT + Theme.LAYOUT.COMPOSER_GUTTER + Theme.DIVIDER_THICKNESS

  local function hintY(runtime)
    local _, _, _, _, y = runtime.composer.padHint.label:GetPoint()
    return y
  end

  -- test_pad_hint_rises_above_a_strip_that_opens_later
  do
    local env = FakeGamepad.New()
    env.install()
    local ok, err = pcall(function()
      local runtime, pane = buildWithPane()
      local baseY = hintY(runtime)
      ConversationPane.SetNotice(pane, "Historical group chat")
      assert(hintY(runtime) == baseY + STRIP_LIFT, "hint raised over the strip, got " .. tostring(hintY(runtime)))
      ConversationPane.SetNotice(pane, "")
      assert(hintY(runtime) == baseY, "hint back in place once the strip closes, got " .. tostring(hintY(runtime)))
    end)
    env.uninstall()
    assert(ok, tostring(err))
  end

  -- test_pad_hint_starts_above_a_strip_already_shown
  do
    local env = FakeGamepad.New()
    env.install()
    local ok, err = pcall(function()
      local plain = buildWithPane()
      local runtime = buildWithPane(function(pane)
        ConversationPane.SetNotice(pane, "Historical group chat")
      end)
      local want = hintY(plain) + STRIP_LIFT
      assert(hintY(runtime) == want, "hint starts raised, want " .. want .. ", got " .. tostring(hintY(runtime)))
    end)
    env.uninstall()
    assert(ok, tostring(err))
  end

  -- test_pad_hint_rises_when_a_reply_strip_opens_while_focused
  do
    local env = FakeGamepad.New()
    env.install()
    local ok, err = pcall(function()
      Flavor.WithPadUI(true, function()
        local runtime, pane = buildWithPane()
        local baseY = hintY(runtime)
        runtime.composer.input:SetFocus()
        ConversationPane.SetReply(pane, { text = "hi", playerName = "Arthas" }, function() end)
        assert(runtime.composer.padHint.frame:IsShown(), "the hint stays shown")
        assert(hintY(runtime) == baseY + STRIP_LIFT, "hint raised over the reply strip, got " .. tostring(hintY(runtime)))
      end)
    end)
    env.uninstall()
    assert(ok, tostring(err))
  end
end
