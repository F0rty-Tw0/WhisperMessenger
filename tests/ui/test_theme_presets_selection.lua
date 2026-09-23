local Theme = require("WhisperMessenger.UI.Theme")

local MODERN_PRESETS = { "wow_default", "elvui_dark", "plumber_warm", "jade_dark", "wow_native" }

local function sameRgb(a, b)
  local epsilon = 0.0001
  return math.abs(a[1] - b[1]) < epsilon and math.abs(a[2] - b[2]) < epsilon and math.abs(a[3] - b[3]) < epsilon
end

-- Hue in [0, 1) of an rgb triple; nil for greys (no hue).
local function hue(color)
  local r, g, b = color[1], color[2], color[3]
  local maxC = math.max(r, g, b)
  local minC = math.min(r, g, b)
  local delta = maxC - minC
  if delta < 0.0001 then
    return nil
  end
  local h
  if maxC == r then
    h = ((g - b) / delta) % 6
  elseif maxC == g then
    h = (b - r) / delta + 2
  else
    h = (r - g) / delta + 4
  end
  return h / 6
end

local function sameHue(a, b)
  local ha, hb = hue(a), hue(b)
  if ha == nil or hb == nil then
    return false
  end
  local diff = math.abs(ha - hb)
  return math.min(diff, 1 - diff) < 0.02
end

return function()
  local previousPreset = Theme.GetPreset()

  -- test_modern_selection_is_faint_accent_tint
  for _, key in ipairs(MODERN_PRESETS) do
    assert(Theme.SetPreset(key) == true, key .. ": expected preset to apply")
    local selected = Theme.COLORS.bg_contact_selected
    assert(sameRgb(selected, Theme.COLORS.accent), key .. ": selected row should be tinted with the accent hue")
    assert(selected[4] <= 0.25, key .. ": selected row tint should be faint (alpha <= 0.25), got " .. tostring(selected[4]))
    assert(Theme.COLORS.accent_bar[4] > selected[4], key .. ": accent bar must read louder than the selection tint")
  end

  -- test_midnight_uses_one_accent_hue
  do
    Theme.SetPreset("wow_default")
    local accent = Theme.COLORS.accent
    assert(sameHue(Theme.COLORS.bg_bubble_out, accent), "wow_default: sent bubble should share the accent hue")
    assert(sameHue(Theme.COLORS.unread_badge, accent), "wow_default: unread badge should share the accent hue")
    assert(sameHue(Theme.COLORS.bg_contact_selected, accent), "wow_default: selection should share the accent hue")
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_theme_presets_selection")
end
