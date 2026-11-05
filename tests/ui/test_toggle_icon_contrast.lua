local Theme = require("WhisperMessenger.UI.Theme")

local HOVER_ACCENT_MIX = 0.15 -- spec: hover circle = 85% toggle_icon_bg + 15% accent
local IDLE_GRAY = { 0.55, 0.55, 0.55 } -- spec: opaque idle back bubble
local FRONT_MIN, BACK_MIN = 4.5, 3

local function linearize(channel)
  if channel <= 0.03928 then
    return channel / 12.92
  end
  return ((channel + 0.055) / 1.055) ^ 2.4
end

local function luminance(color)
  return 0.2126 * linearize(color[1]) + 0.7152 * linearize(color[2]) + 0.0722 * linearize(color[3])
end

local function contrast(a, b)
  local la, lb = luminance(a), luminance(b)
  local hi, lo = math.max(la, lb), math.min(la, lb)
  return (hi + 0.05) / (lo + 0.05)
end

local function mix(bg, accent)
  local out = {}
  for i = 1, 3 do
    out[i] = bg[i] * (1 - HOVER_ACCENT_MIX) + accent[i] * HOVER_ACCENT_MIX
  end
  return out
end

local function check(key, label, a, b, min)
  local ratio = contrast(a, b)
  assert(ratio >= min, string.format("%s: %s (ratio %.2f, need %.1f)", key, label, ratio, min))
end

return function()
  local previous, checked = Theme.GetPreset(), 0
  for _, key in ipairs(Theme.ListPresets()) do
    if not Theme.IsLivePreset(key) then -- EllesmereUI's accent is another addon's
      Theme.SetPreset(key)
      local bg, glyph, accent = Theme.COLORS.toggle_icon_bg, Theme.COLORS.toggle_icon_glyph, Theme.COLORS.accent
      local hover = mix(bg, accent)
      check(key, "idle front on circle", glyph, bg, FRONT_MIN)
      check(key, "idle back on circle", accent, bg, BACK_MIN)
      check(key, "idle gray back on circle", IDLE_GRAY, bg, BACK_MIN)
      check(key, "hover front on hover circle", glyph, hover, FRONT_MIN)
      check(key, "hover back on hover circle", accent, hover, BACK_MIN)
      checked = checked + 1
    end
  end
  assert(checked >= 5, "all five fixed presets checked, got " .. checked)
  Theme.SetPreset(previous)
end
