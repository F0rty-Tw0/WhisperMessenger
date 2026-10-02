local FakeUI = require("tests.helpers.fake_ui")
local EmptyState = require("WhisperMessenger.UI.ContactsList.EmptyState")

local function makeParent()
  local factory = FakeUI.NewFactory()
  return factory.CreateFrame("Frame", "TestParent", nil, nil)
end

local function makeScrolledContent()
  local factory = FakeUI.NewFactory()
  local viewport = factory.CreateFrame("ScrollFrame", "TestViewport", nil, nil)
  local content = factory.CreateFrame("Frame", "TestContent", viewport, nil)
  return content, viewport
end

local function anchorTargets(region)
  local targets = {}
  for _, point in ipairs(region.points or {}) do
    targets[point[1]] = point[2]
  end
  return targets
end

return function()
  -- test_fills_the_visible_viewport_not_the_scrolled_content
  do
    local content, viewport = makeScrolledContent()
    local frame = EmptyState.Create(content)
    assert(frame.allPoints == viewport, "the hint centres in what the player sees, not in the scroll content")
  end

  -- test_label_width_follows_the_pane
  do
    local frame = EmptyState.Create(makeParent())
    local targets = anchorTargets(frame.label)
    assert(targets.LEFT == frame and targets.RIGHT == frame, "label spans the pane width so its text wraps to fit")
    assert(frame.label.width == nil, "no fixed label width")
  end

  -- test_create_returns_frame_with_label
  do
    local parent = makeParent()
    local frame = EmptyState.Create(parent)
    assert(type(frame) == "table", "Create should return a table")
    assert(frame.label ~= nil, "frame should have a .label FontString")
  end

  -- test_create_frame_is_hidden_by_default
  do
    local parent = makeParent()
    local frame = EmptyState.Create(parent)
    assert(frame:IsShown() == false, "empty-state frame should be hidden by default")
  end

  -- test_show_sets_text_and_shows_frame
  do
    local parent = makeParent()
    local frame = EmptyState.Create(parent)
    local msg = "No group chats yet.\nJoin a party or instance to see messages here."
    EmptyState.Show(frame, msg)
    assert(frame:IsShown() == true, "Show should make the frame visible")
    assert(frame.label.text == msg, "Show should set label text to the message")
  end

  -- test_hide_hides_frame
  do
    local parent = makeParent()
    local frame = EmptyState.Create(parent)
    EmptyState.Show(frame, "some message")
    EmptyState.Hide(frame)
    assert(frame:IsShown() == false, "Hide should make the frame invisible")
  end

  -- test_hide_clears_label_text
  do
    local parent = makeParent()
    local frame = EmptyState.Create(parent)
    EmptyState.Show(frame, "some message")
    EmptyState.Hide(frame)
    assert(frame.label.text == "", "Hide should clear the label text")
  end

  -- test_show_applies_text_color_via_theme
  do
    local parent = makeParent()
    local fakeTheme = {
      COLORS = {
        text_secondary = { 0.55, 0.55, 0.62, 1.0 },
      },
    }
    local frame = EmptyState.Create(parent, fakeTheme)
    EmptyState.Show(frame, "test")
    local r, g, b, a = frame.label:GetTextColor()
    assert(r ~= nil, "Show should apply text color to the label")
  end

  -- test_show_hides_when_called_with_nil_message_treated_as_empty
  do
    local parent = makeParent()
    local frame = EmptyState.Create(parent)
    -- Show with empty string should still show the frame (caller's decision)
    EmptyState.Show(frame, "")
    assert(frame:IsShown() == true, "Show with empty string should still show")
  end
end
