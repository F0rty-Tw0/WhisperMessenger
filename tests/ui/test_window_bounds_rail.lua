local WindowBounds = require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local WindowGeometry = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGeometry")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local Schema = require("WhisperMessenger.Persistence.Schema")
local UIHelpers = require("WhisperMessenger.UI.Helpers")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local L = Theme.LAYOUT
local COLLAPSED_MIN = L.CONTACTS_RAIL_WIDTH + Theme.DIVIDER_THICKNESS + L.CONTENT_MIN_WIDTH

local function newGeometry(parent, initialState)
  return WindowGeometry.Create({
    parent = parent,
    theme = Theme,
    clampState = WindowBounds.ClampState,
    clampContactsWidth = LayoutBuilder.ClampContactsWidth,
    captureFramePosition = UIHelpers.captureFramePosition,
    sizeValue = UIHelpers.sizeValue,
    initialState = initialState,
    initialContactsWidth = initialState.contactsWidth,
    initialScale = 1,
  })
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(1920, 1080)

  -- test_collapsed_window_can_shrink_below_the_normal_minimum
  do
    local minWidth = WindowBounds.GetResizeBounds(parent, Theme, 1, true)
    assert(minWidth == COLLAPSED_MIN, "collapsed min width is rail + divider + content min, got " .. tostring(minWidth))
    local expandedMin = WindowBounds.GetResizeBounds(parent, Theme, 1, false)
    assert(expandedMin == L.WINDOW_MIN_WIDTH, "expanded min width is unchanged")
  end

  -- test_clamp_state_keeps_a_narrow_collapsed_window
  do
    local state = WindowBounds.ClampState(parent, { width = COLLAPSED_MIN, height = 500, contactsCollapsed = true }, Theme, 1)
    assert(state.width == COLLAPSED_MIN, "a collapsed window keeps its narrow width, got " .. tostring(state.width))
    local expanded = WindowBounds.ClampState(parent, { width = COLLAPSED_MIN, height = 500 }, Theme, 1)
    assert(expanded.width == L.WINDOW_MIN_WIDTH, "an expanded window still clamps to the normal minimum")
  end

  -- test_new_characters_start_expanded
  assert(Schema.NewCharacterState().window.contactsCollapsed == false, "default window state is expanded")

  -- test_geometry_restores_collapsed_state_and_expanded_width
  do
    local initial = { width = COLLAPSED_MIN, height = 500, contactsWidth = 300, contactsCollapsed = true }
    local geometry = newGeometry(parent, initial)
    assert(geometry.isCollapsed() == true, "geometry starts collapsed from saved state")
    assert(geometry.getContactsWidth() == 300, "narrow collapsed window keeps the expanded width, got " .. tostring(geometry.getContactsWidth()))

    local frame = factory.CreateFrame("Frame", nil, parent)
    frame:SetSize(COLLAPSED_MIN, 500)
    local saved = geometry.buildState(frame)
    assert(saved.contactsCollapsed == true, "collapsed state is persisted")
    assert(saved.contactsWidth == 300, "expanded width is persisted while collapsed, got " .. tostring(saved.contactsWidth))
    assert(saved.width == COLLAPSED_MIN, "narrow width is persisted, got " .. tostring(saved.width))
  end

  -- test_old_saved_state_without_the_flag_is_expanded
  do
    local geometry = newGeometry(parent, { width = 900, height = 560, contactsWidth = 300 })
    assert(geometry.isCollapsed() == false, "missing flag means expanded")
    geometry.setCollapsed(true)
    assert(geometry.isCollapsed() == true, "setCollapsed updates the flag")
  end
end
