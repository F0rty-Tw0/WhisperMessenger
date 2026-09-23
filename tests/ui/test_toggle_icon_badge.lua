local FakeUI = require("tests.helpers.fake_ui")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local icon = ToggleIcon.Create(factory, { parent = parent })

  -- test_badge_has_dark_outline_behind_it: a slightly larger dark disc
  -- separates the badge from the ring it overlaps.
  local outline = icon.badgeOutline
  assert(outline ~= nil, "badge should expose an outline texture")
  local tl, br = outline.points[1], outline.points[2]
  assert(tl[1] == "TOPLEFT" and tl[2] == icon.badge and tl[4] < 0 and tl[5] > 0, "outline should extend past badge top-left")
  assert(br[1] == "BOTTOMRIGHT" and br[2] == icon.badge and br[4] > 0 and br[5] < 0, "outline should extend past badge bottom-right")
  assert(outline.vertexColor and outline.vertexColor[1] < 0.2, "outline should be dark")

  -- test_badge_label_is_centered_in_the_disc: fills the badge and justifies
  -- to the middle instead of floating on its own glyph box.
  local label = icon.badgeLabel
  assert(label.allPoints == icon.badge, "label should fill the badge")
  assert(label.justifyH == "CENTER" and label.justifyV == "MIDDLE", "label should be centred both ways")

  -- test_badge_label_has_no_drop_shadow: the inherited shadow thickens the digits
  assert(label.shadowOffset and label.shadowOffset[1] == 0 and label.shadowOffset[2] == 0, "label shadow should be off")

  -- test_badge_circles_are_not_texel_snapped: snapping jags small scaled circles
  for _, tex in ipairs({ icon.badgeBackground, outline }) do
    assert(tex.snapToPixelGrid == false, "badge circle should not snap to pixel grid")
    assert(tex.texelSnappingBias == 0, "badge circle should not bias texel snapping")
  end

  -- test_widget_uses_inner_glow: no halo spilling outside the ring
  local innerGlow = nil
  for _, child in ipairs(icon.frame.children) do
    for _, region in ipairs(child.children or {}) do
      if region.texturePath == "Interface\\AddOns\\WhisperMessenger\\Media\\inner-glow.png" then
        innerGlow = child
      end
    end
  end
  assert(innerGlow ~= nil, "widget pulse glow should use the inner-glow texture")
  assert(innerGlow.width == icon.frame.width, "inner glow should be exactly the widget size")

  -- test_badge_draws_above_pulse_glow: the glow must never wash over the badge
  local glowLevel = icon.frame:GetFrameLevel() + 5
  assert(icon.badge:GetFrameLevel() > glowLevel, "badge frame level should be above the pulse glow")
end
