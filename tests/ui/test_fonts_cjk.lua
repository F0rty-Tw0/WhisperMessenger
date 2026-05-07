local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

local function setGameFont(name, path, size, flags)
  local fontObj = rawget(_G, name)
  if type(fontObj) == "table" and type(fontObj.SetFont) == "function" then
    fontObj:SetFont(path, size, flags)
  end
end

local function withClientLocale(locale, fn)
  local saved = rawget(_G, "GetLocale")
  rawset(_G, "GetLocale", function()
    return locale
  end)
  local ok, err = pcall(fn)
  rawset(_G, "GetLocale", saved)
  if not ok then
    error(err, 0)
  end
end

return function()
  -- Client locale enUS + addon language koKR: the user's primary fonts lack
  -- Hangul (FRIZQT__.TTF doesn't ship CJK glyphs), so we must inherit the
  -- multi-script FontFamily chain. Tooltip-text proves the chain exists.
  withClientLocale("enUS", function()
    Fonts.Initialize("default")
    setGameFont("GameTooltipText", "Fonts\\TOOLTIP_FAMILY.TTF", 12, "")
    setGameFont("GameFontNormal", "Fonts\\FRIZQT__.TTF", 12, "")

    Fonts.SetLanguage("koKR")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local path = fontObj:GetFont()
    assert(string.find(path, "TOOLTIP_FAMILY") ~= nil, "koKR on enUS client should inherit GameTooltipText, got: " .. tostring(path))
  end)

  -- Same for Chinese (Simplified)
  withClientLocale("enUS", function()
    Fonts.SetLanguage("zhCN")
    local fontObj = _G[Fonts.GetFonts().message_text]
    local path = fontObj:GetFont()
    assert(string.find(path, "TOOLTIP_FAMILY") ~= nil, "zhCN on enUS client should inherit GameTooltipText, got: " .. tostring(path))
  end)

  -- Same for Chinese (Traditional)
  withClientLocale("enUS", function()
    Fonts.SetLanguage("zhTW")
    local fontObj = _G[Fonts.GetFonts().composer_input]
    local path = fontObj:GetFont()
    assert(string.find(path, "TOOLTIP_FAMILY") ~= nil, "zhTW on enUS client should inherit GameTooltipText, got: " .. tostring(path))
  end)

  -- Russian on enUS client: FRIZQT__.TTF on enUS lacks Cyrillic. Must
  -- inherit the family chain so glyphs render — and accept that font-size
  -- customization is lost for the duration. Without this, the slider
  -- would only resize Latin characters; Cyrillic would render at the
  -- fallback font's natural size.
  withClientLocale("enUS", function()
    Fonts.SetLanguage("ruRU")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local path = fontObj:GetFont()
    assert(string.find(path, "TOOLTIP_FAMILY") ~= nil, "ruRU on enUS client should inherit GameTooltipText, got: " .. tostring(path))
  end)

  -- The inheritance override beats explicit font modes that lack the script
  withClientLocale("enUS", function()
    Fonts.SetMode("morpheus")
    Fonts.SetLanguage("koKR")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local path = fontObj:GetFont()
    assert(string.find(path, "TOOLTIP_FAMILY") ~= nil, "koKR override should beat morpheus mode, got: " .. tostring(path))

    Fonts.SetMode("system")
    local sysPath = fontObj:GetFont()
    assert(string.find(sysPath, "TOOLTIP_FAMILY") ~= nil, "koKR override should beat system mode, got: " .. tostring(sysPath))
  end)

  -- Latin languages keep the existing default behavior (FRIZQT-inherited)
  withClientLocale("enUS", function()
    Fonts.SetMode("default")
    Fonts.SetLanguage("enUS")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local path = fontObj:GetFont()
    assert(string.find(path, "FRIZQT") ~= nil, "enUS should fall back to default FRIZQT inheritance, got: " .. tostring(path))
  end)

  -- Client locale matches addon language: the locale-specific primary
  -- fonts already have the script, so SetFont with size customization
  -- works natively. We MUST skip the inheritance override here so users
  -- on a matched client keep the size and outline knobs.
  withClientLocale("ruRU", function()
    setGameFont("GameFontNormal", "Fonts\\FRIZQT___CYR.TTF", 12, "")
    Fonts.SetMode("default")
    Fonts.SetLanguage("ruRU")
    Fonts.SetFontSize(16)
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local path, size = fontObj:GetFont()
    assert(string.find(path, "FRIZQT___CYR") ~= nil, "ruRU on ruRU client should keep native FRIZQT_CYR, got: " .. tostring(path))
    assert(size == 16, "ruRU on ruRU client should respect the size slider, got: " .. tostring(size))
  end)

  -- Same gate for koKR client + koKR addon language
  withClientLocale("koKR", function()
    setGameFont("GameFontNormal", "Fonts\\2002.TTF", 12, "")
    Fonts.SetMode("default")
    Fonts.SetLanguage("koKR")
    Fonts.SetFontSize(14)
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local path, size = fontObj:GetFont()
    assert(string.find(path, "2002") ~= nil, "koKR on koKR client should keep native primary font, got: " .. tostring(path))
    assert(size == 14, "koKR on koKR client should respect the size slider, got: " .. tostring(size))
  end)

  -- "auto" + Korean game locale: client matches resolved language, native
  -- font is used, size customization works.
  withClientLocale("koKR", function()
    setGameFont("GameFontNormal", "Fonts\\2002.TTF", 12, "")
    Fonts.SetLanguage("auto")
    Fonts.SetFontSize(15)
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local path, size = fontObj:GetFont()
    assert(string.find(path, "2002") ~= nil, "auto on koKR client should keep native primary font, got: " .. tostring(path))
    assert(size == 15, "auto on koKR client should respect the size slider, got: " .. tostring(size))
  end)

  -- If GameTooltipText is missing on an exotic Classic build, the resolver
  -- must fall through to GameFontNormal — never nil and never crash.
  withClientLocale("enUS", function()
    local savedTooltip = rawget(_G, "GameTooltipText")
    local savedSystemMed = rawget(_G, "SystemFont_Med1")
    rawset(_G, "GameTooltipText", nil)
    rawset(_G, "SystemFont_Med1", nil)
    setGameFont("GameFontNormal", "Fonts\\GAME_FONT_NORMAL.TTF", 12, "")

    Fonts.SetLanguage("koKR")
    local fontObj = _G[Fonts.GetFonts().contact_name]
    local path = fontObj:GetFont()
    assert(
      string.find(path, "GAME_FONT_NORMAL") ~= nil,
      "koKR should fall back to GameFontNormal when GameTooltipText is missing, got: " .. tostring(path)
    )

    rawset(_G, "GameTooltipText", savedTooltip)
    rawset(_G, "SystemFont_Med1", savedSystemMed)
  end)

  -- Reset to a clean state for downstream tests
  Fonts.Initialize("default")
  setGameFont("GameFontNormal", "Fonts\\FRIZQT__.TTF", 12, "")
end
