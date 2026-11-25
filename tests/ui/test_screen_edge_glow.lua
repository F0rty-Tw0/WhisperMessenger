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
    local top, bottom = frame.points[1], frame.points[2]
    assert(#frame.points == 2, "two anchors, got " .. #frame.points)
    assert(top[1] == "TOPLEFT" and top[2] == parent and top[3] == "TOPLEFT", "top pinned to the parent's top left")
    assert(bottom[1] == "BOTTOMLEFT" and bottom[2] == parent and bottom[3] == "BOTTOMLEFT", "bottom pinned to the parent's bottom left")
    assert(frame.width == 48, "48 px deep, got " .. tostring(frame.width))
    assert(frame.mouseEnabled == false, "the glow takes no mouse")
    assert(frame.frameStrata == "HIGH", "above action bars and trackers")
    assert(frame:GetFrameLevel() == 0, "under the floating button and its preview")
  end

  local function test_right_edge_glow_is_mirrored()
    local surface, state = build()
    state.side = "right"
    surface.refresh()
    local frame = surface.glow.frame
    local top, bottom = frame.points[1], frame.points[2]
    assert(top[1] == "TOPRIGHT" and top[3] == "TOPRIGHT" and bottom[1] == "BOTTOMRIGHT" and bottom[3] == "BOTTOMRIGHT", "anchored to the right edge")
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

  -- A UI-scale change resizes the parent without any refresh: the height comes from the anchors alone.
  local function test_glow_height_comes_from_the_anchors_not_a_size()
    local surface = build()
    assert(surface.glow.frame.height == nil, "no fixed height, got " .. tostring(surface.glow.frame.height))
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
  test_glow_height_comes_from_the_anchors_not_a_size()
  test_glow_uses_the_edge_texture_and_the_slow_cycle()
  test_theme_change_recolours_the_glow()
end
