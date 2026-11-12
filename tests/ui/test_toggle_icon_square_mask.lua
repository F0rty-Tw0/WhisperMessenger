-- The square widget rounds its corners with one mask on the widget frame,
-- put on the square's own textures only, and wears the rounded gold frame.
-- A client without mask textures keeps today's sharp look.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local IconBorder = require("WhisperMessenger.UI.ToggleIcon.IconBorder")
local SquareLook = require("WhisperMessenger.UI.ToggleIcon.SquareLook")

local function widget(state, factoryOptions)
  return ToggleIcon.Create(FakeUI.NewFactory(factoryOptions), {
    getWidgetShape = function()
      return state.shape or "square"
    end,
  })
end

-- Frames keep CreateMaskTexture; every texture they create lacks AddMaskTexture.
local function withoutAddMaskTexture(factory)
  local createFrame = factory.CreateFrame
  return {
    CreateFrame = function(...)
      local frame = createFrame(...)
      local createTexture = frame.CreateTexture
      if createTexture then
        frame.CreateTexture = function(self, ...)
          local texture = createTexture(self, ...)
          texture.AddMaskTexture = nil
          return texture
        end
      end
      return frame
    end,
  }
end

local function maskedTextures(icon)
  local list = { icon.background, icon.squareBackdrop, icon.squareHover, icon.squarePushed, icon.squareFrame }
  for _, edges in ipairs({ icon.squareHoverEdges, icon.squarePushedEdges }) do
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
      table.insert(list, edges[side])
    end
  end
  return list
end

local function unmaskedTextures(icon)
  return { icon.ring, icon.label, icon.accentGlyph, icon.glyphOutline, icon.hoverGlow, icon.pulseTexture }
end

local function assertMasked(icon)
  for index, texture in ipairs(maskedTextures(icon)) do
    local masks = texture.masks
    assert(masks ~= nil and #masks == 1, "texture " .. index .. " has one mask, got " .. tostring(masks and #masks))
    assert(masks[1] == icon.squareMask, "texture " .. index .. " has the widget's mask")
  end
end

return function()
  Theme.SetPreset("wow_default")

  -- test_square_textures_share_one_rounded_mask
  do
    local icon = widget({}, { masks = true })
    local mask = icon.squareMask
    assert(mask ~= nil, "mask created")
    assert(mask.texturePath == SquareLook.MASK_TEXTURE, "rounded mask art, got " .. tostring(mask.texturePath))
    assert(mask.wrapH == "CLAMPTOBLACKADDITIVE" and mask.wrapV == "CLAMPTOBLACKADDITIVE", "mask clamps to black")
    assert(mask.allPoints == icon.frame, "mask covers the button")
    assertMasked(icon)
  end

  -- test_ring_glyphs_and_glows_stay_unmasked
  do
    local icon = widget({}, { masks = true })
    for index, texture in ipairs(unmaskedTextures(icon)) do
      assert(texture.masks == nil, "texture " .. index .. " not masked")
    end
  end

  -- test_masked_square_wears_the_rounded_frame
  do
    local icon = widget({}, { masks = true })
    assert(icon.squareFrame.texturePath == IconBorder.SQUARE_FRAME_ROUNDED_TEXTURE, "rounded frame, got " .. tostring(icon.squareFrame.texturePath))
    icon.refreshTheme()
    assert(icon.squareFrame.texturePath == IconBorder.SQUARE_FRAME_ROUNDED_TEXTURE, "rounded frame after a theme refresh")
    icon.applyIconSize(60)
    assert(icon.squareFrame.texturePath == IconBorder.SQUARE_FRAME_ROUNDED_TEXTURE, "rounded frame after a resize")
    assertMasked(icon)
  end

  -- test_without_masks_the_square_stays_sharp
  do
    local icon = widget({})
    assert(icon.squareMask == nil, "no mask")
    assert(icon.squareFrame.texturePath == IconBorder.SQUARE_FRAME_TEXTURE, "sharp frame, got " .. tostring(icon.squareFrame.texturePath))
    for index, texture in ipairs(maskedTextures(icon)) do
      assert(texture.masks == nil, "texture " .. index .. " not masked")
    end
    for index, texture in ipairs(unmaskedTextures(icon)) do
      assert(texture.masks == nil, "unmasked texture " .. index .. " not masked")
    end
  end

  -- test_unmaskable_square_frame_keeps_sharp_art
  do
    local icon = ToggleIcon.Create(withoutAddMaskTexture(FakeUI.NewFactory({ masks = true })), {
      getWidgetShape = function()
        return "square"
      end,
    })
    assert(icon.squareMask ~= nil, "frames still create the mask")
    assert(icon.squareFrame.texturePath == IconBorder.SQUARE_FRAME_TEXTURE, "sharp frame, got " .. tostring(icon.squareFrame.texturePath))
  end

  -- test_circle_keeps_the_mask_and_hides_the_frame
  do
    local state = {}
    local icon = widget(state, { masks = true })
    state.shape = "circle"
    icon.refreshTheme()
    assert(icon.squareFrame.shown == false, "frame hidden on the circle")
    assertMasked(icon)
    state.shape = "square"
    icon.refreshTheme()
    assert(icon.squareFrame.shown == true, "frame back on the square")
    assertMasked(icon)
  end

  Theme.SetPreset(Theme.DEFAULT_PRESET)
end
