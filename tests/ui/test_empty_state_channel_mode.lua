local FakeUI = require("tests.helpers.fake_ui")
local HeaderElements = require("WhisperMessenger.UI.ConversationPane.HeaderElements")
local FindUI = require("tests.helpers.find_ui")

local CHANNELS_TITLE = "Channels"
local CHANNELS_SUBTITLE = "The channels you tick in the Chats settings show up here. Pick a channel on the left."

local function findButton(emptyState)
  for _, child in ipairs(emptyState.children) do
    if child.frameType == "Button" then
      return child
    end
  end
  return nil
end

return function()
  local factory = FakeUI.NewFactory()
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(600, 420)

  -- test_channels_mode_shows_channel_copy
  do
    local emptyState = HeaderElements.createEmptyState(pane, nil, factory)
    emptyState.setMode("channels")
    assert(FindUI.text(emptyState, CHANNELS_TITLE) ~= nil, "channels mode should show the channel title")
    assert(FindUI.text(emptyState, CHANNELS_SUBTITLE) ~= nil, "channels mode should show the channel subtitle")
    assert(FindUI.text(emptyState, "Welcome to Whisper Messenger") == nil, "channels mode should drop the whisper welcome")
  end

  -- test_channels_mode_hides_start_whisper_button
  do
    local emptyState = HeaderElements.createEmptyState(pane, nil, factory)
    emptyState.setMode("channels")
    local btn = assert(findButton(emptyState), "expected start whisper button")
    assert(btn.shown == false, "start whisper button should be hidden in channels mode")
  end

  -- test_set_language_keeps_channels_copy
  do
    local emptyState = HeaderElements.createEmptyState(pane, nil, factory)
    emptyState.setMode("channels")
    emptyState.setLanguage()
    assert(FindUI.text(emptyState, CHANNELS_SUBTITLE) ~= nil, "language refresh should keep channels copy")
  end
end
