local CompactRuntime = require("tests.helpers.compact_runtime")

-- A click on the floating button while its whisper preview shows opens that
-- whisper's chat, like a click on the preview itself. With no preview the
-- button keeps its plain toggle.

local KEY = CompactRuntime.KEY

-- Live whisper with the window never built yet.
local function receiveWhisper(runtime)
  local finishSlide = CompactRuntime.FinishSlide
  rawset(CompactRuntime, "FinishSlide", function() end)
  local ok, err = pcall(CompactRuntime.ReceiveWhisper, runtime)
  rawset(CompactRuntime, "FinishSlide", finishSlide)
  assert(ok, err)
end

local function clickButton(runtime)
  local saved = rawget(_G, "IsShiftKeyDown")
  rawset(_G, "IsShiftKeyDown", function()
    return false
  end)
  local button = runtime.icon.frame
  local ok, err = pcall(button.scripts.OnClick, button, "LeftButton")
  rawset(_G, "IsShiftKeyDown", saved)
  assert(ok, err)
  if runtime.window and runtime.window.compactViewport then
    CompactRuntime.FinishSlide(runtime)
  end
end

local function previewShown(runtime)
  return runtime.icon.previewFrame:IsShown()
end

return function()
  -- test_compact_button_click_with_a_preview_opens_its_chat
  CompactRuntime.Run(nil, function(runtime)
    receiveWhisper(runtime)
    assert(previewShown(runtime), "the preview shows the whisper")
    clickButton(runtime)
    assert(runtime.window.frame:IsShown(), "the window opens")
    assert(runtime.activeConversationKey == KEY, "selected: " .. tostring(runtime.activeConversationKey))
    assert(runtime.window.contentPane:IsShown(), "the chat is on screen, not the list")
    assert(not previewShown(runtime), "the preview is gone")
  end)

  -- test_classic_button_click_with_a_preview_opens_its_chat_from_another_tab
  CompactRuntime.Run({ compactLayout = false }, function(runtime)
    runtime.toggle()
    runtime.window.setTabMode("groups")
    runtime.toggle()
    receiveWhisper(runtime)
    assert(previewShown(runtime), "the preview shows the whisper")
    clickButton(runtime)
    assert(runtime.window.frame:IsShown(), "the window opens")
    assert(runtime.activeConversationKey == KEY, "selected: " .. tostring(runtime.activeConversationKey))
    assert(runtime.window.getTabMode() == "whispers", "on the whisper's tab")
    assert(not previewShown(runtime), "the preview is gone")
  end)

  -- test_classic_docked_button_shows_no_preview_over_the_open_window_and_a_click_closes_it
  CompactRuntime.Run({ compactLayout = false }, function(runtime)
    runtime.toggle()
    runtime.window.setTabMode("groups")
    receiveWhisper(runtime)
    assert(runtime.icon.isRiding(), "the button is docked on the open window")
    assert(not previewShown(runtime), "a docked button suppresses its card, like compact")
    clickButton(runtime)
    assert(not runtime.window.frame:IsShown(), "the click closes the window")
  end)

  -- test_classic_button_click_on_the_open_window_without_a_preview_closes_it
  CompactRuntime.Run({ compactLayout = false }, function(runtime)
    runtime.toggle()
    assert(not previewShown(runtime), "no preview")
    clickButton(runtime)
    assert(not runtime.window.frame:IsShown(), "the window closes")
  end)

  -- test_compact_button_click_without_a_preview_still_opens_the_list
  CompactRuntime.Run(nil, function(runtime)
    assert(not previewShown(runtime), "no preview")
    clickButton(runtime)
    assert(runtime.window.frame:IsShown(), "the window opens")
    assert(runtime.activeConversationKey == nil, "nothing selected")
    assert(runtime.window.contactsPane:IsShown() and not runtime.window.contentPane:IsShown(), "on the list")
  end)

  -- test_compact_button_click_on_a_new_whisper_with_previews_off_opens_the_list
  CompactRuntime.Run({ showWidgetMessagePreview = false }, function(runtime)
    receiveWhisper(runtime)
    assert(not previewShown(runtime), "previews are off")
    clickButton(runtime)
    assert(runtime.activeConversationKey == nil, "nothing selected")
    assert(runtime.window.contactsPane:IsShown() and not runtime.window.contentPane:IsShown(), "on the list")
  end)
end
