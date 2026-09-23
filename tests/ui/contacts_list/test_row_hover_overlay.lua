local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local RowHoverOverlay = require("WhisperMessenger.UI.ContactsList.RowHoverOverlay")

-- Row whose textures support the Retail SetGradient(orientation, min, max) API.
local function newGradientRow()
  local factory = FakeUI.NewFactory()
  local row = factory.CreateFrame("Button", nil, nil)
  local createTexture = row.CreateTexture
  row.created = 0
  rawset(row, "CreateTexture", function(self, ...)
    self.created = self.created + 1
    local texture = createTexture(self, ...)
    function texture:SetGradient(orientation, minColor, maxColor)
      self.gradient = { orientation = orientation, from = minColor, to = maxColor }
    end
    return texture
  end)
  return row
end

local function fakeCreateColor(r, g, b, a)
  return { r = r, g = g, b = b, a = a }
end

return function()
  local previousPreset = Theme.GetPreset()
  local previousCreateColor = _G.CreateColor
  Theme.SetPreset("wow_default")

  -- test_selection_is_accent_gradient_fading_right
  _G.CreateColor = fakeCreateColor
  do
    local row = newGradientRow()
    RowHoverOverlay.ensure(row)
    local g = row.selectionFill.gradient
    local accent = Theme.COLORS.bg_contact_selected
    assert(g and g.orientation == "HORIZONTAL", "selection uses a horizontal gradient")
    -- Base carries the intended colour; the gradient only scales its alpha.
    local base = row.selectionFill.color
    assert(base[1] == accent[1] and base[4] == accent[4], "selection base is the accent tint, never opaque white")
    assert(g.from.a == 1 and g.to.a == 0, "gradient fades the tint from full on the left to 0 on the right")
    assert(accent[4] >= 0.12 and accent[4] <= 0.18, "left alpha is about 0.15")

    -- Hover is animated by HoverFade, so it must be a flat fill (no gradient).
    assert(row.hoverFill.gradient == nil, "hover overlay never uses SetGradient")
    local hover = row.hoverFill.color
    assert(hover[1] == 1 and hover[2] == 1 and hover[3] == 1, "hover is a flat white fill")
    row.selected = false
    RowHoverOverlay.update(row, true)
    assert(row.hoverFill.alpha <= 0.08, "hover's effective alpha is faint")
    RowHoverOverlay.update(row, false)

    local created = row.created
    RowHoverOverlay.ensure(row)
    assert(row.created == created, "overlays are created once per pooled row")

    row.selected = true
    RowHoverOverlay.update(row, false)
    assert(row.selectionFill.shown == true, "selected row shows the gradient")
    row.selected = false
    RowHoverOverlay.update(row, false)
    assert(row.selectionFill.shown == false, "unselected row hides the gradient")
  end

  -- test_flat_fallback_without_gradient_api
  _G.CreateColor = nil
  do
    local factory = FakeUI.NewFactory()
    local row = factory.CreateFrame("Button", nil, nil)
    RowHoverOverlay.ensure(row)
    local c = row.selectionFill.color
    local accent = Theme.COLORS.bg_contact_selected
    assert(c[1] == accent[1] and c[4] == accent[4], "fallback: flat accent tint")
  end

  -- test_azeroth_uses_the_overlays_too
  Theme.SetPreset("wow_native")
  do
    local factory = FakeUI.NewFactory()
    local row = factory.CreateFrame("Button", nil, nil)
    RowHoverOverlay.ensure(row)
    row.selected = true
    assert(RowHoverOverlay.update(row, true) == true, "azeroth: overlays own hover/selection")
    assert(row.selectionFill.shown == true, "azeroth: selection gradient shown")
  end

  _G.CreateColor = previousCreateColor
  Theme.SetPreset(previousPreset)
  print("PASS: test_row_hover_overlay")
end
