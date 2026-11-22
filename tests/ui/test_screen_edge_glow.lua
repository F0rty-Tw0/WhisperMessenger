-- The edge glow surface: lit only while the window is hidden and whispers are
-- unread, along the full height of the chosen screen edge.
local AnimatedFactory = require("tests.helpers.animated_factory")
local ScreenEdgeGlow = require("WhisperMessenger.UI.ToggleIcon.ScreenEdgeGlow")
local ScreenEdgeSurface = require("WhisperMessenger.UI.ToggleIcon.ScreenEdgeSurface")
local Theme = require("WhisperMessenger.UI.Theme")

local function build(settings)
  local factory = AnimatedFactory.newAnimatedFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(1920, 1080)
  local state = { side = "left", shown = false }
  settings = settings or {}
  local surface = ScreenEdgeSurface.Create(factory, parent, {
    theme = Theme,
    settings = settings,
    getSide = function()
      return state.side
    end,
    isWindowShown = function()
      return state.shown
    end,
  })
  return surface, state, settings, parent
end

return function()
  local function test_glows_while_hidden_with_unread_whispers()
    local surface = build()
    surface.setUnreadCount(3, 2)
    assert(surface.glow.pulse.animation.playing == true, "unread whispers light the glow")
  end

  local function test_no_glow_while_the_window_shows()
    local surface, state = build()
    surface.setUnreadCount(3, 2)
    state.shown = true
    surface.refresh()
    assert(surface.glow.pulse.animation.playing == false, "a shown window stops the glow")
    assert(surface.glow.frame.shown == false, "and hides it")
  end

  local function test_panel_badges_alone_do_not_glow()
    local surface = build()
    surface.setUnreadCount(2, 0)
    assert(surface.glow.pulse.animation.playing == false, "panel badges alone stay dark")
  end

  local function test_edge_glow_off_stops_it()
    local surface, _, settings = build()
    surface.setUnreadCount(3, 2)
    settings.edgeGlow = false
    surface.refresh()
    assert(surface.glow.pulse.animation.playing == false, "edgeGlow = false stops the glow")
  end

  local function test_no_side_no_glow()
    local surface, state = build()
    surface.setUnreadCount(3, 2)
    state.side = nil
    surface.refresh()
    assert(surface.glow.pulse.animation.playing == false, "no side, no glow")
  end

  local function test_glow_covers_the_full_left_edge()
    local surface, _, _, parent = build()
    local frame = surface.glow.frame
    local p = frame.point
    assert(p[1] == "LEFT" and p[2] == parent and p[3] == "LEFT", "anchored LEFT to the parent's LEFT")
    assert(frame.width == 48, "48 px deep, got " .. tostring(frame.width))
    assert(frame.height == 1080, "the full 1080, got " .. tostring(frame.height))
    assert(frame.mouseEnabled == false, "the glow takes no mouse")
    assert(frame.frameStrata == "BACKGROUND", "background strata")
  end

  local function test_right_edge_glow_is_mirrored()
    local surface, state = build()
    state.side = "right"
    surface.refresh()
    local frame = surface.glow.frame
    assert(frame.point[1] == "RIGHT" and frame.point[3] == "RIGHT", "anchored RIGHT")
    local c = surface.glow.pulse.glowTexture.texCoords
    assert(c[1] == 1 and c[2] == 0 and c[3] == 0 and c[4] == 1, "mirrored texture coordinates")
  end

  local function test_left_edge_glow_is_not_mirrored()
    local surface = build()
    local c = surface.glow.pulse.glowTexture.texCoords
    assert(c[1] == 0 and c[2] == 1 and c[3] == 0 and c[4] == 1, "plain texture coordinates")
  end

  local function test_there_is_no_handle()
    local surface = build()
    assert(surface.handle == nil, "the surface has no handle")
    assert(pcall(require, "WhisperMessenger.UI.ToggleIcon.ScreenEdgeHandle") == false, "no handle module")
  end

  local function test_glow_follows_a_parent_height_change()
    local surface, _, _, parent = build()
    parent:SetSize(1920, 900)
    surface.refresh()
    assert(surface.glow.frame.height == 900, "the full 900, got " .. tostring(surface.glow.frame.height))
  end

  local function test_glow_uses_the_edge_texture_and_the_slow_cycle()
    local surface = build()
    local pulse = surface.glow.pulse
    assert(pulse.glowTexture.texturePath == ScreenEdgeGlow.TEXTURE, "the edge texture")
    assert(ScreenEdgeGlow.TEXTURE == "Interface\\AddOns\\WhisperMessenger\\Media\\edge-glow.png", "texture path")
    local sum = 0
    for _, anim in ipairs(pulse.animation.animations) do
      sum = sum + anim.duration + anim.endDelay
    end
    assert(math.abs(sum - 3) < 1e-9, "3 s cycle, got " .. sum)
  end

  local function test_theme_change_recolours_the_glow()
    local surface = build()
    surface.refreshTheme({ COLORS = { accent = { 0.1, 0.2, 0.3, 1 } } })
    local vc = surface.glow.pulse.glowTexture.vertexColor
    assert(vc and vc[1] == 0.1 and vc[2] == 0.2 and vc[3] == 0.3, "the glow takes the new accent")
  end

  test_glows_while_hidden_with_unread_whispers()
  test_there_is_no_handle()
  test_no_glow_while_the_window_shows()
  test_panel_badges_alone_do_not_glow()
  test_edge_glow_off_stops_it()
  test_no_side_no_glow()
  test_glow_covers_the_full_left_edge()
  test_right_edge_glow_is_mirrored()
  test_left_edge_glow_is_not_mirrored()
  test_glow_follows_a_parent_height_change()
  test_glow_uses_the_edge_texture_and_the_slow_cycle()
  test_theme_change_recolours_the_glow()
end
