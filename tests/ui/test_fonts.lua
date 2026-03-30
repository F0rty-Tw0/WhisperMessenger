local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

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
    assert(
      string.find(fonts.contact_name, "^WM_") ~= nil,
      "test_font_keys_are_wm_objects: contact_name should start with WM_, got: " .. tostring(fonts.contact_name)
    )
    assert(
      string.find(fonts.message_text, "^WM_") ~= nil,
      "test_font_keys_are_wm_objects: message_text should start with WM_, got: " .. tostring(fonts.message_text)
    )
    assert(
      string.find(fonts.composer_input, "^WM_") ~= nil,
      "test_font_keys_are_wm_objects: composer_input should start with WM_, got: " .. tostring(fonts.composer_input)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_default_mode_uses_friz_quadrata
  -- -----------------------------------------------------------------------
  do
    Fonts.Initialize()
    Fonts.SetMode("default")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    assert(fontObj ~= nil, "test_default_mode_uses_friz: WM font object should exist in _G")
    local path = fontObj:GetFont()
    assert(
      string.find(path, "FRIZQT__") ~= nil,
      "test_default_mode_uses_friz: default mode should use FRIZQT__, got: " .. tostring(path)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_system_mode_uses_arial_narrow
  -- -----------------------------------------------------------------------
  do
    Fonts.Initialize()
    Fonts.SetMode("system")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local path = fontObj:GetFont()
    assert(
      string.find(path, "ARIALN") ~= nil,
      "test_system_mode_uses_arial: system mode should use ARIALN, got: " .. tostring(path)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_custom_mode_inherits_from_game_fonts
  -- -----------------------------------------------------------------------
  do
    -- Simulate ElvUI changing GameFontNormal's font
    _G.GameFontNormal:SetFont("Fonts\\CUSTOM_ELVUI.TTF", 12, "")
    Fonts.Initialize()
    Fonts.SetMode("custom")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local path = fontObj:GetFont()
    assert(
      string.find(path, "CUSTOM_ELVUI") ~= nil,
      "test_custom_mode_inherits: custom mode should inherit from GameFont, got: " .. tostring(path)
    )
    -- Restore default
    _G.GameFontNormal:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
  end

  -- -----------------------------------------------------------------------
  -- test_set_mode_updates_all_font_objects
  -- -----------------------------------------------------------------------
  do
    Fonts.Initialize()
    Fonts.SetMode("system")
    local fonts = Fonts.GetFonts()
    -- Check multiple font objects all switched to ARIALN
    for key, name in pairs(fonts) do
      local obj = _G[name]
      assert(obj ~= nil, "test_set_mode_updates_all: " .. key .. " object should exist")
      local path = obj:GetFont()
      assert(
        string.find(path, "ARIALN") ~= nil,
        "test_set_mode_updates_all: " .. key .. " should use ARIALN in system mode, got: " .. tostring(path)
      )
    end
  end

  -- -----------------------------------------------------------------------
  -- test_set_mode_preserves_sizes
  -- -----------------------------------------------------------------------
  do
    Fonts.Initialize()
    Fonts.SetMode("default")
    local fonts = Fonts.GetFonts()
    local normalObj = _G[fonts.contact_name]
    local largeObj = _G[fonts.header_name]
    local _, normalSize = normalObj:GetFont()
    local _, largeSize = largeObj:GetFont()

    Fonts.SetMode("system")
    local _, normalSizeAfter = normalObj:GetFont()
    local _, largeSizeAfter = largeObj:GetFont()

    assert(
      normalSize == normalSizeAfter,
      "test_preserves_sizes: normal size should stay " .. tostring(normalSize) .. ", got: " .. tostring(normalSizeAfter)
    )
    assert(
      largeSize == largeSizeAfter,
      "test_preserves_sizes: large size should stay " .. tostring(largeSize) .. ", got: " .. tostring(largeSizeAfter)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_initialize_with_mode
  -- -----------------------------------------------------------------------
  do
    Fonts.Initialize("system")
    assert(
      Fonts.GetMode() == "system",
      "test_initialize_with_mode: should accept initial mode, got: " .. tostring(Fonts.GetMode())
    )
  end

  print("  All font mode tests passed")
end
