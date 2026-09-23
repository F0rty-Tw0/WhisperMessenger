local Theme = require("WhisperMessenger.UI.Theme")
local Presets = require("WhisperMessenger.UI.Theme.Presets")

local MODERN_PRESETS = { "wow_default", "elvui_dark", "plumber_warm", "jade_dark", "wow_native" }

-- Hairlines, hover states and the scrollbar must be neutral: accent is kept
-- for the selection bar, active tab underline and Send icon only.
local NEUTRAL_TOKENS = {
  "divider",
  "contacts_divider",
  "contacts_border_right",
  "composer_pane_border",
  "window_border",
  "contacts_divider_hover",
  "bg_contact_hover",
  "scrollbar",
  "scrollbar_hover",
  "ghost_button_border",
  "ghost_button_fill_hover",
}

local MAX_CHROMA = 0.06

local function chroma(color)
  return math.max(color[1], color[2], color[3]) - math.min(color[1], color[2], color[3])
end

return function()
  local previousPreset = Theme.GetPreset()

  -- test_modern_hairlines_and_hovers_are_neutral
  for _, key in ipairs(MODERN_PRESETS) do
    Theme.SetPreset(key)
    for _, token in ipairs(NEUTRAL_TOKENS) do
      local color = Theme.COLORS[token]
      assert(type(color) == "table", key .. ": missing token " .. token)
      assert(chroma(color) <= MAX_CHROMA, key .. ": " .. token .. " should be a neutral grey, chroma " .. tostring(chroma(color)))
    end
  end

  -- test_modern_scrollbar_is_quiet
  for _, key in ipairs(MODERN_PRESETS) do
    Theme.SetPreset(key)
    assert(Theme.COLORS.scrollbar[4] <= 0.3, key .. ": idle scrollbar thumb should be low alpha")
    assert(Theme.COLORS.scrollbar_hover[4] > Theme.COLORS.scrollbar[4], key .. ": hovered thumb should read stronger")
  end

  -- test_modern_neutrals_are_white_plus_alpha
  local function isWhite(color)
    return color[1] == 1 and color[2] == 1 and color[3] == 1
  end
  for _, key in ipairs(MODERN_PRESETS) do
    Theme.SetPreset(key)
    for _, token in ipairs({ "divider", "window_border", "composer_pane_border" }) do
      local c = Theme.COLORS[token]
      assert(isWhite(c) and c[4] >= 0.06 and c[4] <= 0.10, key .. ": " .. token .. " should be white at 0.06-0.10 alpha")
    end
    local hover = Theme.COLORS.bg_contact_hover
    assert(isWhite(hover) and hover[4] >= 0.04 and hover[4] <= 0.06, key .. ": hover fill should be white at 0.04-0.06 alpha")
    assert(Theme.COLORS.text_primary[4] == 1, key .. ": primary text stays opaque")
    local pinned = Theme.COLORS.bg_contact_pinned
    local accent = Theme.COLORS.accent
    local isAccent = pinned[1] == accent[1] and pinned[2] == accent[2] and pinned[3] == accent[3]
    assert(isAccent and pinned[4] == 0.05, key .. ": pinned rows carry a faint accent tint (0.05)")
  end
  for _, key in ipairs({ "wow_default", "elvui_dark", "jade_dark", "wow_native" }) do
    Theme.SetPreset(key)
    local secondary = Theme.COLORS.text_secondary
    assert(isWhite(secondary) and secondary[4] >= 0.5 and secondary[4] <= 0.55, key .. ": secondary text should be white at ~0.5-0.55")
  end

  -- test_jade_then_midnight_leaves_no_jade_values
  do
    Theme.SetPreset("jade_dark")
    Theme.SetPreset("wow_default")
    local expected = assert(Presets.Get("wow_default"), "expected wow_default palette")
    for token, color in pairs(Theme.COLORS) do
      local want = expected[token]
      assert(want ~= nil, "unexpected token " .. token)
      for i = 1, 4 do
        assert(color[i] == want[i], "token " .. token .. " channel " .. i .. " leaked from jade_dark: " .. tostring(color[i]))
      end
    end
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_theme_presets_neutral")
end
