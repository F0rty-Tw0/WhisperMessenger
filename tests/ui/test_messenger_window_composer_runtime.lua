-- The composer runtime builds the composer and holds back its focus on a quiet show.
local FakeUI = require("tests.helpers.fake_ui")
local ComposerRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ComposerRuntime")

local function build()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)
  local composerPane = factory.CreateFrame("Frame", nil, frame)
  composerPane:SetSize(400, 80)
  local calls = {}
  local conversation = { tag = "conversation" }
  local settingsConfig = {}
  local runtime = ComposerRuntime.Create(factory, {
    frame = frame,
    layout = { composerPane = composerPane },
    settingsConfig = settingsConfig,
    windowOptions = {},
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
  })
  return runtime, frame, calls, conversation, settingsConfig
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

  -- test_pane_view_reads_show_channel_context_live
  do
    local _, _, _, conversation, settingsConfig = build()
    assert(conversation.isChannelContextShown() == true, "shown by default")
    settingsConfig.showChannelContext = false
    assert(conversation.isChannelContextShown() == false, "reads the setting at call time, not at build time")
    settingsConfig.showChannelContext = true
    assert(conversation.isChannelContextShown() == true, "shown again once switched back on")
  end
end
