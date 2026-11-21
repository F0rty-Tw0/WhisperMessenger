-- With the background off, hovering the square lights up its edge (the
-- unread pulse's square art, in the accent) on the square's box, as the
-- circle's halo reads along its ring. The bubble halo is not shown on the
-- square. Both EllesmereUI paths glow the same.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local SquareLook = require("WhisperMessenger.UI.ToggleIcon.SquareLook")
local Shape = require("tests.helpers.toggle_icon_shape")
local withProfile = require("tests.helpers.ellesmere_profile")

local function widget(state)
  return Shape.iconWithShape(function()
    return state.shape or "square"
  end, {
    getIconBackground = function()
      return state.background == true
    end,
    getIconBorder = function()
      return state.border
    end,
  }, FakeUI.NewFactory({ masks = true }))
end

local function enter(icon)
  icon.frame:GetScript("OnEnter")(icon.frame)
end

local function inAccent(texture)
  local c, accent = texture.vertexColor or {}, Theme.COLORS.accent
  return c[1] == accent[1] and c[2] == accent[2] and c[3] == accent[3]
end

local function edgeGlowOnBox(icon, outset)
  local glow = icon.hoverGlow
  return glow.shown == true and glow.texturePath == SquareLook.SQUARE_GLOW_TEXTURE and Shape.onBox(glow, icon.frame, outset)
end

return function()
  Theme.SetPreset("wow_default")

  -- test_square_hover_without_background_glows_along_the_edge
  do
    local name = "test_square_hover_without_background_glows_along_the_edge"
    local icon = widget({})
    assert(icon.hoverGlow.shown ~= true, name .. ": no glow before hover")
    enter(icon)
    assert(icon.hoverGlow.shown == true, name .. ": glow on hover")
    assert(icon.hoverGlow.texturePath == SquareLook.SQUARE_GLOW_TEXTURE, name .. ": square edge art, got " .. tostring(icon.hoverGlow.texturePath))
    assert(Shape.onBox(icon.hoverGlow, icon.frame, 3.15), name .. ": on the 1.15x box")
    assert(inAccent(icon.hoverGlow), name .. ": in the accent")
    assert(icon.hoverGlow.masks == nil, name .. ": not masked")
  end

  -- test_edge_glow_at_button_size_with_the_border_off
  do
    local icon = widget({ border = false })
    enter(icon)
    assert(Shape.coversButton(icon.hoverGlow, icon.frame), "test_edge_glow_at_button_size_with_the_border_off")
  end

  -- test_edge_glow_hides_on_leave
  do
    local name = "test_edge_glow_hides_on_leave"
    local icon = widget({})
    enter(icon)
    assert(edgeGlowOnBox(icon, 3.15), name .. ": edge glow on the box while hovered")
    icon.frame:GetScript("OnLeave")(icon.frame)
    assert(icon.hoverGlow.shown == false, name .. ": hidden on leave")
  end

  -- test_edge_glow_on_the_ellesmere_path
  withProfile({}, function()
    local icon = widget({})
    enter(icon)
    assert(edgeGlowOnBox(icon, 3.15), "test_edge_glow_on_the_ellesmere_path")
  end)

  -- test_edge_glow_follows_the_icon_size
  do
    local icon = widget({})
    enter(icon)
    icon.applyIconSize(60)
    assert(edgeGlowOnBox(icon, 4.5), "test_edge_glow_follows_the_icon_size")
  end

  -- test_circle_to_square_while_hovered_shows_the_edge_glow
  do
    local name = "test_circle_to_square_while_hovered_shows_the_edge_glow"
    local state = { shape = "circle" }
    local icon = widget(state)
    enter(icon)
    assert(icon.hoverGlow.texturePath == SquareLook.BUBBLE_GLOW_TEXTURE, name .. ": halo on the circle")
    state.shape = "square"
    icon.refreshTheme()
    assert(edgeGlowOnBox(icon, 3.15), name .. ": edge glow on the square")
  end

  -- test_edge_glow_stays_with_the_unread_pulse
  do
    local name = "test_edge_glow_stays_with_the_unread_pulse"
    local icon = widget({})
    enter(icon)
    icon.setUnreadCount(2)
    assert(edgeGlowOnBox(icon, 3.15), name .. ": edge glow still on the box")
    assert(Shape.fillsWithSquareGlow(icon.pulseTexture, icon.frame), name .. ": pulse along the edge")
  end

  Theme.SetPreset(Theme.DEFAULT_PRESET)
end
