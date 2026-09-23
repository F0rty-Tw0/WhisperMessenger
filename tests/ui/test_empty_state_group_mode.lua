local FakeUI = require("tests.helpers.fake_ui")
local HeaderElements = require("WhisperMessenger.UI.ConversationPane.HeaderElements")
local FindUI = require("tests.helpers.find_ui")

local GROUPS_TITLE = "Group Chats"
local GROUPS_SUBTITLE = "Party, raid, instance and guild chats show up here. Join a group or pick a chat on the left."

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

  -- test_groups_mode_shows_group_copy
  do
    local emptyState = HeaderElements.createEmptyState(pane, nil, factory)
    emptyState.setMode("groups")
    assert(FindUI.text(emptyState, GROUPS_TITLE) ~= nil, "groups mode should show group title")
    assert(FindUI.text(emptyState, GROUPS_SUBTITLE) ~= nil, "groups mode should show group subtitle")
  end

  -- test_groups_mode_hides_start_whisper_button
  do
    local emptyState = HeaderElements.createEmptyState(pane, nil, factory)
    emptyState.setMode("groups")
    local btn = assert(findButton(emptyState), "expected start whisper button")
    assert(btn.shown == false, "start whisper button should be hidden in groups mode")
  end

  -- test_whispers_mode_restores_welcome_copy_and_button
  do
    local emptyState = HeaderElements.createEmptyState(pane, nil, factory)
    emptyState.setMode("groups")
    emptyState.setMode("whispers")
    assert(FindUI.text(emptyState, "Welcome to WhisperMessenger") ~= nil, "whispers mode should restore welcome title")
    local btn = assert(findButton(emptyState), "expected start whisper button")
    assert(btn.shown == true, "start whisper button should be shown in whispers mode")
  end

  -- test_set_language_keeps_groups_copy
  do
    local emptyState = HeaderElements.createEmptyState(pane, nil, factory)
    emptyState.setMode("groups")
    emptyState.setLanguage()
    assert(FindUI.text(emptyState, GROUPS_TITLE) ~= nil, "language refresh should keep groups copy")
  end
end
