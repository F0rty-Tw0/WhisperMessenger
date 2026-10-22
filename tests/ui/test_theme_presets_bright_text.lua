local Presets = require("WhisperMessenger.UI.Theme.Presets")

-- Text that sits on a filled surface (sent bubbles, selected and hovered
-- option buttons) must read as near-white on every preset. Azeroth keeps its
-- gold for titles only.
local BRIGHT_TOKENS = { "text_sent", "option_button_text_hover", "option_button_text_active" }
local OTHER_PRESETS = { "wow_default", "elvui_dark", "plumber_warm", "jade_dark" }

local function sameColor(a, b)
  return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

local function isNearWhite(color)
  return color[1] >= 0.9 and color[2] >= 0.9 and color[3] >= 0.9
end

return function()
  -- test_azeroth_text_on_fills_is_near_white
  local azeroth = assert(Presets.Get("wow_native"), "azeroth preset should exist")
  for _, token in ipairs(BRIGHT_TOKENS) do
    assert(isNearWhite(azeroth[token]), "azeroth: " .. token .. " should be near-white")
  end

  -- test_azeroth_titles_stay_gold
  assert(sameColor(azeroth.text_title, azeroth.accent), "azeroth: titles should keep the gold accent")

  -- test_other_presets_text_on_fills_match_their_title_colour
  for _, key in ipairs(OTHER_PRESETS) do
    local preset = assert(Presets.Get(key), key .. " preset should exist")
    for _, token in ipairs(BRIGHT_TOKENS) do
      assert(sameColor(preset[token], preset.text_title), key .. ": " .. token .. " should stay as before")
    end
  end
end
