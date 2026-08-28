local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

local function setGameFont(path, size, flags)
  local gameFontNormal = rawget(_G, "GameFontNormal")
  assert(type(gameFontNormal) == "table", "expected GameFontNormal table")
  assert(type(gameFontNormal.SetFont) == "function", "expected GameFontNormal:SetFont")
  gameFontNormal:SetFont(path, size, flags)
end

local function withSharedMedia(fonts, fn)
  local savedLibStub = rawget(_G, "LibStub")
  local lsm = fonts
      and {
        List = function(_, mediaType)
          assert(mediaType == "font", "expected LibSharedMedia font list")
          local names = {}
          for name in pairs(fonts) do
            names[#names + 1] = name
          end
          return names
        end,
        Fetch = function(_, mediaType, name, noDefault)
          assert(mediaType == "font", "expected LibSharedMedia font fetch")
          assert(noDefault == true, "expected LibSharedMedia fetch without default")
          return fonts[name]
        end,
      }
    or nil

  rawset(
    _G,
    "LibStub",
    setmetatable({}, {
      __call = function(_, name)
        if name == "LibSharedMedia-3.0" then
          return lsm
        end
      end,
    })
  )

  local ok, err = pcall(fn)
  rawset(_G, "LibStub", savedLibStub)
  if not ok then
    error(err, 0)
  end
end

local function withoutLibStub(fn)
  local savedLibStub = rawget(_G, "LibStub")
  rawset(_G, "LibStub", nil)

  local ok, err = pcall(fn)
  rawset(_G, "LibStub", savedLibStub)
  if not ok then
    error(err, 0)
  end
end
return function()
  -- test_default_mode_on_init

  do
    Fonts.Initialize()
    assert(Fonts.GetMode() == "default", "test_default_mode_on_init: mode should be 'default', got: " .. tostring(Fonts.GetMode()))
  end

  -- test_font_keys_are_wm_objects

  do
    Fonts.Initialize()
    local fonts = Fonts.GetFonts()
    for _, key in ipairs({ "contact_name", "message_text", "composer_input" }) do
      assert(string.find(fonts[key], "^WM_") ~= nil, "test_font_keys: " .. key .. " should start with WM_, got: " .. tostring(fonts[key]))
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
    assert(string.find(path, "CYR") ~= nil, "test_default_locale: should follow locale game font, got: " .. tostring(path))
    setGameFont("Fonts\\FRIZQT__.TTF", 12, "")
  end

  -- test_list_font_families_returns_default_then_case_insensitive_lsm_names

  do
    withSharedMedia({
      zebra = "Fonts\\ZEBRA.TTF",
      alpha = "Fonts\\ALPHA.TTF",
      Bravo = "Fonts\\BRAVO.TTF",
    }, function()
      assert(type(Fonts.ListFontFamilies) == "function", "test_list_font_families: Fonts.ListFontFamilies contract is required")
      local families = Fonts.ListFontFamilies()
      assert(families[1].key == "default", "test_list_font_families: Default key should remain default")
      assert(families[1].label == "Default", "test_list_font_families: Default should be first")
      assert(families[2].label == "alpha", "test_list_font_families: LSM names should sort case-insensitively")
      assert(families[3].label == "Bravo", "test_list_font_families: LSM names should sort case-insensitively")
      assert(families[4].label == "zebra", "test_list_font_families: LSM names should sort case-insensitively")
    end)
  end

  -- test_missing_libstub_lists_default_and_falls_back_without_error

  do
    withoutLibStub(function()
      assert(type(Fonts.ListFontFamilies) == "function", "test_missing_libstub: Fonts.ListFontFamilies contract is required")
      local families = Fonts.ListFontFamilies()
      assert(#families == 1, "test_missing_libstub: absent LibStub should list only Default")
      assert(families[1].key == "default", "test_missing_libstub: Default key should remain default")
      assert(families[1].label == "Default", "test_missing_libstub: Default should be listed")

      setGameFont("Fonts\\CUSTOM_ELVUI.TTF", 12, "")
      Fonts.Initialize("Unavailable Font")
      local path = _G[Fonts.GetFonts().contact_name]:GetFont()
      assert(Fonts.GetMode() == "default", "test_missing_libstub: custom name should select default mode")
      assert(string.find(path, "CUSTOM_ELVUI") ~= nil, "test_missing_libstub: custom name should apply default path, got: " .. tostring(path))
      setGameFont("Fonts\\FRIZQT__.TTF", 12, "")
    end)
  end

  -- test_absent_shared_media_falls_back_to_default

  do
    withSharedMedia(nil, function()
      setGameFont("Fonts\\CUSTOM_ELVUI.TTF", 18, "OUTLINE")
      Fonts.Initialize("Some Registered Font")
      local fontObj = _G[Fonts.GetFonts().contact_name]
      local path = fontObj:GetFont()
      assert(Fonts.GetMode() == "default", "test_absent_lsm: unavailable library should select default mode")
      assert(string.find(path, "CUSTOM_ELVUI") ~= nil, "test_absent_lsm: should inherit game font, got: " .. tostring(path))
      setGameFont("Fonts\\FRIZQT__.TTF", 12, "")
    end)
  end

  -- test_registered_shared_media_font_fetches_path_for_all_wm_objects

  do
    local selectedPath = "Interface\\AddOns\\SharedMedia\\OpenSans.ttf"
    withSharedMedia({ ["Open Sans"] = selectedPath }, function()
      Fonts.Initialize("Open Sans")
      assert(Fonts.GetMode() == "Open Sans", "test_lsm_mode: registered name should become current mode")
      for key, name in pairs(Fonts.GetFonts()) do
        local obj = _G[name]
        assert(obj ~= nil, "test_lsm_all_wm_objects: " .. key .. " object should exist")
        local path = obj:GetFont()
        assert(path == selectedPath, "test_lsm_all_wm_objects: " .. key .. " should use fetched path, got: " .. tostring(path))
      end
    end)
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

  -- test_initialize_with_registered_shared_media_name

  do
    withSharedMedia({ ["Fira Sans"] = "Interface\\AddOns\\SharedMedia\\FiraSans.ttf" }, function()
      Fonts.Initialize("Fira Sans")
      assert(Fonts.GetMode() == "Fira Sans", "test_init_mode: should accept registered SharedMedia name, got: " .. tostring(Fonts.GetMode()))
    end)
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
    assert(Fonts.GetFontSize() == 12, "test_get_font_size: default should be 12, got: " .. tostring(Fonts.GetFontSize()))
    Fonts.SetFontSize(16)
    assert(Fonts.GetFontSize() == 16, "test_get_font_size: after set should be 16, got: " .. tostring(Fonts.GetFontSize()))
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
    assert(Fonts.GetOutline() == "NONE", "test_get_outline: default should be NONE, got: " .. tostring(Fonts.GetOutline()))
    Fonts.SetOutline("OUTLINE")
    assert(Fonts.GetOutline() == "OUTLINE", "test_get_outline: after set should be OUTLINE, got: " .. tostring(Fonts.GetOutline()))
  end

  -- test_missing_and_legacy_names_fall_back_to_default

  do
    withSharedMedia({ ["Open Sans"] = "Interface\\AddOns\\SharedMedia\\OpenSans.ttf" }, function()
      setGameFont("Fonts\\CUSTOM_ELVUI.TTF", 12, "")
      for _, name in ipairs({ "Missing Font", "system", "morpheus" }) do
        Fonts.SetMode(name)
        local path = _G[Fonts.GetFonts().contact_name]:GetFont()
        assert(Fonts.GetMode() == "default", "test_legacy_fallback: " .. name .. " should select default mode")
        assert(string.find(path, "CUSTOM_ELVUI") ~= nil, "test_legacy_fallback: " .. name .. " should use default path, got: " .. tostring(path))
      end
      setGameFont("Fonts\\FRIZQT__.TTF", 12, "")
    end)
  end

  -- test_registered_font_preserves_size_and_outline

  do
    local selectedPath = "Interface\\AddOns\\SharedMedia\\OpenSans.ttf"
    withSharedMedia({ ["Open Sans"] = selectedPath }, function()
      Fonts.Initialize("default")
      Fonts.SetFontSize(16)
      Fonts.SetOutline("THICKOUTLINE")
      Fonts.SetMode("Open Sans")

      local path, size, flags = _G[Fonts.GetFonts().contact_name]:GetFont()
      assert(path == selectedPath, "test_lsm_size_outline: should use fetched path, got: " .. tostring(path))
      assert(size == 16, "test_lsm_size_outline: size should persist, got: " .. tostring(size))
      assert(flags == "THICKOUTLINE", "test_lsm_size_outline: outline should persist, got: " .. tostring(flags))
    end)
  end

  -- test_default_font_color_is_default

  do
    Fonts.Initialize("default")
    assert(Fonts.GetFontColor() == "default", "test_default_font_color: should be 'default', got: " .. tostring(Fonts.GetFontColor()))
  end

  -- test_set_font_color_returns_preset_key

  do
    Fonts.Initialize("default")
    Fonts.SetFontColor("gold")
    assert(Fonts.GetFontColor() == "gold", "test_set_font_color: should be 'gold', got: " .. tostring(Fonts.GetFontColor()))
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
    assert(Fonts.GetFontColor() == "default", "test_font_color_unknown: should fall back to 'default', got: " .. tostring(Fonts.GetFontColor()))
  end

  print("  All font mode tests passed")
end
