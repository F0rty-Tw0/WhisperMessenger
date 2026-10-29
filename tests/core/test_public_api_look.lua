local PublicApi = require("WhisperMessenger.Core.PublicApi")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Presets = require("WhisperMessenger.UI.Theme.Presets")

local KEYS = {
  "bg_primary",
  "bg_secondary",
  "bg_header",
  "bg_input",
  "divider",
  "contacts_divider",
  "bg_contact_selected",
  "bg_contact_hover",
  "scrollbar",
  "scrollbar_hover",
}

local function build(settings)
  return PublicApi.Build({ accountState = { settings = settings or {} } })
end

local function isColor(value)
  return type(value) == "table"
    and type(value[1]) == "number"
    and type(value[2]) == "number"
    and type(value[3]) == "number"
    and type(value[4]) == "number"
end

return function()
  -- test_look_has_hud_and_all_ten_colors
  do
    local look = build().GetLook()
    assert(type(look) == "table", "GetLook returns a table")
    assert(look.hud == "off", "hud defaults to off, got " .. tostring(look.hud))
    for _, key in ipairs(KEYS) do
      assert(isColor(look.colors[key]), key .. " is a 4-number color")
    end
  end

  -- test_colors_match_the_current_theme
  do
    local look = build().GetLook()
    for _, key in ipairs(KEYS) do
      for i = 1, 4 do
        assert(look.colors[key][i] == Theme.COLORS[key][i], key .. "[" .. i .. "] matches Theme.COLORS")
      end
    end
  end

  -- test_hud_follows_the_configured_style
  do
    local api = build()
    Hud.Configure("classic")
    local hud = api.GetLook().hud
    Hud.Configure("off")
    assert(hud == "classic", "hud is classic, got " .. tostring(hud))
  end

  -- test_hud_reports_retail_when_the_client_has_its_templates
  do
    local api = build()
    local saved = rawget(_G, "C_XMLUtil")
    rawset(_G, "C_XMLUtil", {
      GetTemplateInfo = function()
        return {}
      end,
    })
    Hud.Configure("retail")
    local hud = api.GetLook().hud
    Hud.Configure("off")
    rawset(_G, "C_XMLUtil", saved)
    assert(hud == "retail", "hud is retail, got " .. tostring(hud))
  end

  -- test_colors_follow_a_preset_switch
  do
    local api = build()
    local savedPreset = Theme.GetPreset()
    local before = api.GetLook().colors.bg_primary[1]
    Theme.SetPreset(Presets.ELVUI_DARK)
    local after = api.GetLook().colors.bg_primary[1]
    local expected = Theme.COLORS.bg_primary[1]
    Theme.SetPreset(savedPreset)
    assert(expected ~= before, "the test presets must differ in bg_primary")
    assert(after == expected, "same api follows the new preset, got " .. tostring(after))
  end

  -- test_each_call_returns_a_new_table
  do
    local api = build()
    local first, second = api.GetLook(), api.GetLook()
    assert(first ~= second, "new look table per call")
    assert(first.colors ~= second.colors, "new colors table per call")
  end

  -- test_mutating_the_answer_leaves_the_theme_unchanged
  do
    local look = build().GetLook()
    local original = Theme.COLORS.bg_primary[1]
    assert(look.colors.bg_primary ~= Theme.COLORS.bg_primary, "color is a copy, not WM's table")
    look.colors.bg_primary[1] = 99
    assert(Theme.COLORS.bg_primary[1] == original, "Theme.COLORS untouched")
  end

  -- test_missing_theme_key_is_left_out
  do
    local saved = Theme.COLORS.scrollbar_hover
    Theme.COLORS.scrollbar_hover = nil
    local ok, look = pcall(build().GetLook)
    Theme.COLORS.scrollbar_hover = saved
    assert(ok, tostring(look))
    assert(look.colors.scrollbar_hover == nil, "missing key left out")
    assert(isColor(look.colors.bg_primary), "other keys still there")
  end

  -- test_internal_error_returns_nil
  do
    local saved = Theme.COLORS
    Theme.COLORS = setmetatable({}, {
      __index = function()
        error("boom")
      end,
    })
    local ok, look = pcall(build().GetLook)
    Theme.COLORS = saved
    assert(ok, "GetLook never throws: " .. tostring(look))
    assert(look == nil, "error answers nil, got " .. tostring(look))
  end

  -- test_integration_disabled_returns_no_look
  do
    local look = build({ allowAddonIntegration = false }).GetLook()
    assert(type(look) ~= "table", "refused GetLook is not a table, got " .. type(look))
  end
end
