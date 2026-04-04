local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

local function setGameFont(path, size, flags)
  local gameFontNormal = rawget(_G, "GameFontNormal")
  assert(type(gameFontNormal) == "table", "expected GameFontNormal table")
  assert(type(gameFontNormal.SetFont) == "function", "expected GameFontNormal:SetFont")
  gameFontNormal:SetFont(path, size, flags)
end
return function()
  -- -----------------------------------------------------------------------
  -- test_default_mode_on_init
  -- -----------------------------------------------------------------------
  do
    Fonts.Initialize()
    assert(
      Fonts.GetMode() == "default",
      "test_default_mode_on_init: mode should be 'default', got: " .. tostring(Fonts.GetMode())
    )
  end

  -- -----------------------------------------------------------------------
  -- test_font_keys_are_wm_objects
  -- -----------------------------------------------------------------------
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

  -- -----------------------------------------------------------------------
  -- test_default_mode_inherits_game_font (multilingual via SetFontObject)
  -- -----------------------------------------------------------------------
  do
    Fonts.Initialize("default")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    assert(fontObj ~= nil, "test_default: WM font object should exist")
    local path = fontObj:GetFont()
    assert(string.find(path, "FRIZQT") ~= nil, "test_default: should inherit game font path, got: " .. tostring(path))
  end

  -- -----------------------------------------------------------------------
  -- test_default_follows_locale_font (multilingual)
  -- -----------------------------------------------------------------------
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

  -- -----------------------------------------------------------------------
  -- test_system_mode_uses_arialn
  -- -----------------------------------------------------------------------
  do
    Fonts.SetMode("system")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local path = fontObj:GetFont()
    assert(string.find(path, "ARIALN") ~= nil, "test_system: should use ARIALN, got: " .. tostring(path))
  end

  -- -----------------------------------------------------------------------
  -- test_unknown_mode_falls_back_to_default_behavior
  -- -----------------------------------------------------------------------
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

  -- -----------------------------------------------------------------------
  -- test_mode_switch_default_vs_system_on_vanilla_client
  -- -----------------------------------------------------------------------
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

  -- -----------------------------------------------------------------------
  -- test_set_mode_updates_all_font_objects
  -- -----------------------------------------------------------------------
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

  -- -----------------------------------------------------------------------
  -- test_composer_font_matches_ui_font_in_default_mode
  -- -----------------------------------------------------------------------
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

  -- -----------------------------------------------------------------------
  -- test_initialize_with_mode
  -- -----------------------------------------------------------------------
  do
    Fonts.Initialize("system")
    assert(
      Fonts.GetMode() == "system",
      "test_init_mode: should accept initial mode, got: " .. tostring(Fonts.GetMode())
    )
  end

  print("  All font mode tests passed")
end
