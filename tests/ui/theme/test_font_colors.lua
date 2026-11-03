local FontColors = require("WhisperMessenger.UI.Theme.FontColors")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

return function()
  -- test_list_keeps_menu_order_and_copies_presets
  local list = FontColors.List()
  local keys = {}
  for i, preset in ipairs(list) do
    keys[i] = preset.key
  end
  assert(table.concat(keys, ",") == "default,gold,light_blue,soft_green,purple,rose", "menu order, got " .. table.concat(keys, ","))
  list[2].label = "changed"
  assert(FontColors.List()[2].label == "Gold", "List returns copies")

  -- test_get_returns_preset_or_nil
  assert(FontColors.Get("gold").rgba[2] == 0.82, "gold preset")
  assert(FontColors.Get("default").rgba == nil, "default has no color")
  assert(FontColors.Get("nope") == nil, "unknown key")

  -- test_fonts_color_api_reads_the_presets
  Fonts.SetFontColor("rose")
  assert(Fonts.GetFontColorRGBA()[1] == 1 and Fonts.GetFontColorRGBA()[2] == 0.65, "rose rgba")
  Fonts.SetFontColor("nope")
  assert(Fonts.GetFontColorRGBA() == nil, "unknown key falls back to default")
  assert(#Fonts.ListFontColorPresets() == 6, "Fonts lists the presets")
end
