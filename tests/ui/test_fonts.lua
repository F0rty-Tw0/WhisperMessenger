local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

local function setGameFont(path, size, flags)
  local gameFontNormal = rawget(_G, "GameFontNormal")
  assert(type(gameFontNormal) == "table", "expected GameFontNormal table")
  assert(type(gameFontNormal.SetFont) == "function", "expected GameFontNormal:SetFont")
  gameFontNormal:SetFont(path, size, flags)
end
return function()

  -- test_default_mode_on_init

  do
    Fonts.Initialize()
    assert(
      Fonts.GetMode() == "default",
      "test_default_mode_on_init: mode should be 'default', got: " .. tostring(Fonts.GetMode())
    )
  end

  -- test_font_keys_are_wm_objects

  do
    Fonts.Initialize()
    local fonts = Fonts.GetFonts()
    for _, key in ipairs({ "contact_name", "message_text", "composer_input" }) do
      assert(
        string.find(fonts[key], "^WM_") ~= nil,
        "test_font_keys: " .. key .. " should start with WM_, got: " .. tostring(fonts[key])
      )
    end
  end

  -- test_default_mode_inherits_game_font (multilingual via SetFontObject)

  do
    Fonts.Initialize("default")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    assert(fontObj ~= nil, "test_default: WM font object should exist")
    local path = fontObj:GetFont()
    assert(string.find(path, "FRIZQT") ~= nil, "test_default: should inherit game font path, got: " .. tostring(path))
  end

  -- test_default_follows_locale_font (multilingual)

  do
    setGameFont("Fonts\\FRIZQT___CYR.TTF", 12, "")
    Fonts.SetMode("default")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local path = fontObj:GetFont()
    assert(
      string.find(path, "CYR") ~= nil,
      "test_default_locale: should follow locale game font, got: " .. tostring(path)
    )
    setGameFont("Fonts\\FRIZQT__.TTF", 12, "")
  end

  -- test_system_mode_uses_arialn

  do
    Fonts.SetMode("system")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local path = fontObj:GetFont()
    assert(string.find(path, "ARIALN") ~= nil, "test_system: should use ARIALN, got: " .. tostring(path))
  end

  -- test_unknown_mode_falls_back_to_default_behavior

  do
    setGameFont("Fonts\\CUSTOM_ELVUI.TTF", 18, "OUTLINE")
    Fonts.SetMode("custom")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local path, size = fontObj:GetFont()
    assert(
      string.find(path, "CUSTOM_ELVUI") ~= nil,
      "test_unknown_mode: should inherit game font, got: " .. tostring(path)
    )
    assert(size == 12, "test_unknown_mode: should use controlled size, got: " .. tostring(size))
    setGameFont("Fonts\\FRIZQT__.TTF", 12, "")
  end

  -- test_mode_switch_default_vs_system_on_vanilla_client

  do
    -- On a vanilla client (no ElvUI), game fonts are FRIZQT
    Fonts.SetMode("default")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local defaultPath = fontObj:GetFont()

    Fonts.SetMode("system")
    local systemPath = fontObj:GetFont()

    assert(defaultPath ~= systemPath, "test_switch: default and system should differ")
    assert(string.find(defaultPath, "FRIZQT") ~= nil, "test_switch: default should be FRIZQT")
    assert(string.find(systemPath, "ARIALN") ~= nil, "test_switch: system should be ARIALN")
  end

  -- test_set_mode_updates_all_font_objects

  do
    Fonts.SetMode("system")
    local fonts = Fonts.GetFonts()
    for key, name in pairs(fonts) do
      local obj = _G[name]
      assert(obj ~= nil, "test_updates_all: " .. key .. " object should exist")
      local path = obj:GetFont()
      assert(
        string.find(path, "ARIALN") ~= nil,
        "test_updates_all: " .. key .. " should use ARIALN in system mode, got: " .. tostring(path)
      )
    end
  end

  -- test_composer_font_matches_ui_font_in_default_mode

  do
    Fonts.SetMode("default")
    local fonts = Fonts.GetFonts()
    local uiObj = _G[fonts.contact_name]
    local composerObj = _G[fonts.composer_input]
    local uiPath = uiObj:GetFont()
    local composerPath = composerObj:GetFont()
    assert(
      string.find(composerPath, "FRIZQT") ~= nil,
      "test_composer_default: composer should use game font (FRIZQT), got: " .. tostring(composerPath)
    )
    assert(
      string.find(uiPath, "FRIZQT") ~= nil and string.find(composerPath, "FRIZQT") ~= nil,
      "test_composer_default: composer and UI fonts should both inherit the game font"
    )
  end

  -- test_initialize_with_mode

  do
    Fonts.Initialize("system")
    assert(
      Fonts.GetMode() == "system",
      "test_init_mode: should accept initial mode, got: " .. tostring(Fonts.GetMode())
    )
  end

  -- test_set_font_size_scales_all_objects

  do
    Fonts.Initialize("default")
    Fonts.SetFontSize(14)
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local _, size = fontObj:GetFont()
    assert(size == 14, "test_set_font_size: contact_name base should be 14, got: " .. tostring(size))

    local smallObj = _G[Fonts.GetFonts().contact_preview]
    local _, smallSize = smallObj:GetFont()
    assert(smallSize == 12, "test_set_font_size: contact_preview (small) should be 12, got: " .. tostring(smallSize))

    local largeObj = _G[Fonts.GetFonts().header_name]
    local _, largeSize = largeObj:GetFont()
    assert(largeSize == 18, "test_set_font_size: header_name (large) should be 18, got: " .. tostring(largeSize))
  end

  -- test_get_font_size_returns_current

  do
    Fonts.Initialize("default")
    assert(
      Fonts.GetFontSize() == 12,
      "test_get_font_size: default should be 12, got: " .. tostring(Fonts.GetFontSize())
    )
    Fonts.SetFontSize(16)
    assert(
      Fonts.GetFontSize() == 16,
      "test_get_font_size: after set should be 16, got: " .. tostring(Fonts.GetFontSize())
    )
  end

  -- test_set_outline_applies_to_all_objects

  do
    Fonts.Initialize("default")
    Fonts.SetOutline("OUTLINE")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local _, _, flags = fontObj:GetFont()
    assert(flags == "OUTLINE", "test_set_outline: flags should be OUTLINE, got: " .. tostring(flags))

    local smallObj = _G[Fonts.GetFonts().contact_preview]
    local _, _, smallFlags = smallObj:GetFont()
    assert(smallFlags == "OUTLINE", "test_set_outline: small flags should be OUTLINE, got: " .. tostring(smallFlags))
  end

  -- test_set_outline_thick

  do
    Fonts.Initialize("default")
    Fonts.SetOutline("THICKOUTLINE")
    local fontObj = _G[Fonts.GetFonts().message_text]
    local _, _, flags = fontObj:GetFont()
    assert(flags == "THICKOUTLINE", "test_set_outline_thick: flags should be THICKOUTLINE, got: " .. tostring(flags))
  end

  -- test_set_outline_none_clears_flags

  do
    Fonts.SetOutline("OUTLINE")
    Fonts.SetOutline("NONE")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local _, _, flags = fontObj:GetFont()
    assert(flags == "", "test_set_outline_none: flags should be empty, got: " .. tostring(flags))
  end

  -- test_get_outline_returns_current

  do
    Fonts.Initialize("default")
    assert(
      Fonts.GetOutline() == "NONE",
      "test_get_outline: default should be NONE, got: " .. tostring(Fonts.GetOutline())
    )
    Fonts.SetOutline("OUTLINE")
    assert(
      Fonts.GetOutline() == "OUTLINE",
      "test_get_outline: after set should be OUTLINE, got: " .. tostring(Fonts.GetOutline())
    )
  end

  -- test_morpheus_mode_uses_morpheus_font

  do
    Fonts.SetMode("morpheus")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local path = fontObj:GetFont()
    assert(
      string.find(path, "MORPHEUS") ~= nil,
      "test_morpheus_mode: should use MORPHEUS font, got: " .. tostring(path)
    )
  end

  -- test_font_size_persists_across_mode_switch

  do
    Fonts.Initialize("default")
    Fonts.SetFontSize(16)
    Fonts.SetMode("system")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local _, size = fontObj:GetFont()
    assert(
      size == 16,
      "test_size_persists_mode_switch: size should persist as 16 after mode switch, got: " .. tostring(size)
    )
  end

  -- test_outline_persists_across_mode_switch

  do
    Fonts.Initialize("default")
    Fonts.SetOutline("THICKOUTLINE")
    Fonts.SetMode("system")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local _, _, flags = fontObj:GetFont()
    assert(
      flags == "THICKOUTLINE",
      "test_outline_persists_mode_switch: outline should persist after mode switch, got: " .. tostring(flags)
    )
  end

  -- test_default_font_color_is_default

  do
    Fonts.Initialize("default")
    assert(
      Fonts.GetFontColor() == "default",
      "test_default_font_color: should be 'default', got: " .. tostring(Fonts.GetFontColor())
    )
  end

  -- test_set_font_color_returns_preset_key

  do
    Fonts.Initialize("default")
    Fonts.SetFontColor("gold")
    assert(
      Fonts.GetFontColor() == "gold",
      "test_set_font_color: should be 'gold', got: " .. tostring(Fonts.GetFontColor())
    )
  end

  -- test_get_font_color_rgba_returns_nil_for_default

  do
    Fonts.Initialize("default")
    local rgba = Fonts.GetFontColorRGBA()
    assert(rgba == nil, "test_font_color_rgba_default: should be nil for 'default', got: " .. tostring(rgba))
  end

  -- test_get_font_color_rgba_returns_table_for_gold

  do
    Fonts.Initialize("default")
    Fonts.SetFontColor("gold")
    local rgba = Fonts.GetFontColorRGBA()
    assert(type(rgba) == "table", "test_font_color_rgba_gold: should be a table")
    assert(rgba[1] == 1, "test_font_color_rgba_gold: r should be 1, got: " .. tostring(rgba[1]))
    assert(rgba[2] > 0.8 and rgba[2] < 0.85, "test_font_color_rgba_gold: g should be ~0.82, got: " .. tostring(rgba[2]))
    assert(rgba[3] == 0, "test_font_color_rgba_gold: b should be 0, got: " .. tostring(rgba[3]))
  end

  -- test_list_font_color_presets

  do
    local presets = Fonts.ListFontColorPresets()
    assert(type(presets) == "table", "test_list_presets: should return a table")
    local found = {}
    for _, p in ipairs(presets) do
      found[p.key] = true
    end
    assert(found["default"], "test_list_presets: should include 'default'")
    assert(found["gold"], "test_list_presets: should include 'gold'")
    assert(found["light_blue"], "test_list_presets: should include 'light_blue'")
    assert(found["soft_green"], "test_list_presets: should include 'soft_green'")
    assert(found["purple"], "test_list_presets: should include 'purple'")
    assert(found["rose"], "test_list_presets: should include 'rose'")
  end

  -- test_set_font_color_unknown_falls_back_to_default

  do
    Fonts.Initialize("default")
    Fonts.SetFontColor("nonexistent")
    assert(
      Fonts.GetFontColor() == "default",
      "test_font_color_unknown: should fall back to 'default', got: " .. tostring(Fonts.GetFontColor())
    )
  end

  print("  All font mode tests passed")
end
