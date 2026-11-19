-- Without a readable EllesmereUI Action Bars profile the square fills, hovers
-- and presses like the circle: its fill is the icon background, hover lifts
-- it toward the accent, a press does nothing, and there is no backdrop and no
-- EllesmereUI effect. The path is picked on every repaint.
local Theme = require("WhisperMessenger.UI.Theme")
local SquareLook = require("WhisperMessenger.UI.ToggleIcon.SquareLook")
local IconArt = require("WhisperMessenger.UI.ToggleIcon.IconArt")
local ButtonLook = require("WhisperMessenger.UI.Theme.EllesmereButtonLook")
local Shape = require("tests.helpers.toggle_icon_shape")
local withProfile = require("tests.helpers.ellesmere_profile")

local sameColor = Shape.sameColor

local function widget(state)
  return Shape.iconWithShape(function()
    return state.shape or "square"
  end, {})
end

local function enter(icon)
  icon.frame:GetScript("OnEnter")(icon.frame)
end

local function lifted(icon)
  return sameColor(icon.background.vertexColor, IconArt.ResolveHoverBgColor())
end

return function()
  Theme.SetPreset("wow_default")

  -- test_circle_path_fill_is_the_icon_background
  do
    local name = "test_circle_path_fill_is_the_icon_background"
    local icon = widget({})
    assert(icon.background.texturePath == SquareLook.SQUARE_TEXTURE, name .. ": square art")
    assert(icon.background.shown == true, name .. ": shown")
    assert(sameColor(icon.background.vertexColor, Theme.COLORS.toggle_icon_bg), name .. ": the icon background color")
  end

  -- test_circle_path_hover_lifts_the_fill
  do
    local name = "test_circle_path_hover_lifts_the_fill"
    local icon = widget({})
    enter(icon)
    assert(lifted(icon), name .. ": lifted toward the accent")
    icon.frame:GetScript("OnLeave")(icon.frame)
    assert(sameColor(icon.background.vertexColor, Theme.COLORS.toggle_icon_bg), name .. ": back on leave")
  end

  -- test_circle_path_press_does_nothing
  do
    local name = "test_circle_path_press_does_nothing"
    local icon = widget({})
    enter(icon)
    icon.frame:GetScript("OnMouseDown")(icon.frame)
    assert(lifted(icon), name .. ": still the lift while held")
    assert(icon.squareHover.shown ~= true, name .. ": no EllesmereUI hover effect")
    assert(icon.squarePushed.shown ~= true, name .. ": no EllesmereUI pushed effect")
    icon.frame:GetScript("OnMouseUp")(icon.frame)
    assert(lifted(icon), name .. ": still the lift on release")
  end

  -- test_circle_path_unread_keeps_the_lift
  do
    local icon = widget({})
    enter(icon)
    icon.setUnreadCount(2)
    assert(lifted(icon), "test_circle_path_unread_keeps_the_lift")
  end

  -- test_switch_to_square_while_hovered_keeps_the_lift
  do
    local state = { shape = "circle" }
    local icon = widget(state)
    enter(icon)
    state.shape = "square"
    icon.refreshTheme()
    assert(lifted(icon), "test_switch_to_square_while_hovered_keeps_the_lift")
  end

  -- test_ellesmere_theme_without_action_bars_uses_the_circle_path
  Shape.withEllesmere(function()
    local name = "test_ellesmere_theme_without_action_bars_uses_the_circle_path"
    Theme.SetPreset("ellesmere_ui")
    local icon = widget({})
    enter(icon)
    assert(lifted(icon), name .. ": lifted like the circle")
    assert(icon.squareHover.shown ~= true, name .. ": no EllesmereUI hover effect")
  end)
  Theme.SetPreset("wow_default")

  -- test_profile_appears_on_repaint
  do
    local name = "test_profile_appears_on_repaint"
    local icon = widget({})
    withProfile({}, function()
      icon.refreshTheme()
      assert(sameColor(icon.background.vertexColor, ButtonLook.Read().bg), name .. ": EllesmereUI's slot fill")
      assert(icon.squareBackdrop:IsShown(), name .. ": backdrop under the slot fill")
    end)
  end

  -- test_profile_gone_returns_to_the_circle_path
  do
    local name = "test_profile_gone_returns_to_the_circle_path"
    local icon
    withProfile({}, function()
      icon = widget({})
    end)
    icon.refreshTheme()
    assert(sameColor(icon.background.vertexColor, Theme.COLORS.toggle_icon_bg), name .. ": the icon background color")
    assert(not icon.squareBackdrop:IsShown(), name .. ": no backdrop")
  end

  -- test_profile_gone_unread_change_returns_to_the_circle_path
  do
    local name = "test_profile_gone_unread_change_returns_to_the_circle_path"
    local icon
    withProfile({}, function()
      icon = widget({})
    end)
    icon.setUnreadCount(0)
    assert(sameColor(icon.background.vertexColor, Theme.COLORS.toggle_icon_bg), name .. ": the icon background color")
    assert(not icon.squareBackdrop:IsShown(), name .. ": no backdrop")
  end

  -- test_profile_gone_resize_returns_to_the_circle_path
  do
    local name = "test_profile_gone_resize_returns_to_the_circle_path"
    local icon
    withProfile({}, function()
      icon = widget({})
    end)
    icon.applyIconSize(48)
    assert(sameColor(icon.background.vertexColor, Theme.COLORS.toggle_icon_bg), name .. ": the icon background color")
    assert(not icon.squareBackdrop:IsShown(), name .. ": no backdrop")
  end

  Theme.SetPreset(Theme.DEFAULT_PRESET)
end
