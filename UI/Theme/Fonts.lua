local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FontFamilies = ns.ThemeFontFamilies or require("WhisperMessenger.UI.Theme.FontFamilies")
local FontColors = ns.ThemeFontColors or require("WhisperMessenger.UI.Theme.FontColors")
local GlyphCoverage = ns.ThemeGlyphCoverage or require("WhisperMessenger.UI.Theme.GlyphCoverage")

local Fonts = {}

-- WM_ font objects act as stable references that all FontStrings point at.
-- Mode switching calls SetFontObject (for the engine's glyph fallback chain)
-- then SetFont (to propagate the change to every FontString).

local FRIZQT_PATH = "Fonts\\FRIZQT__.TTF"

-- Languages whose script may not be present in the user's locale-specific
-- primary font (FRIZQT__.TTF on an English Classic client lacks CJK glyphs
-- AND lacks Cyrillic). For these we inherit from a Blizzard FontObject
-- whose FontFamily chain includes the script as a fallback — the same
-- chain GameTooltip uses, which is why tooltip text renders correctly on
-- any client. We do NOT call SetFont(path, size, flags) here because that
-- would replace the chain with a single path and the engine renders
-- fallback glyphs at the fallback font's natural size — the size slider
-- would only move glyphs covered by the primary path, leaving the rest
-- frozen. Trade-off: font-size and outline customization don't apply
-- when the addon's display language differs from the WoW client locale.
local MULTI_SCRIPT_LANGUAGES = {
  koKR = true,
  zhCN = true,
  zhTW = true,
  ruRU = true,
}

-- Probed in order. The first FontObject that exists wins. GameTooltipText
-- is the most reliable on Classic — its FontFamily chain carries CJK
-- and Cyrillic fallback on every flavor we support.
local MULTI_SCRIPT_FONT_OBJECT_NAMES = {
  "GameTooltipText",
  "SystemFont_Med1",
  "GameFontNormal",
}

local DEFAULT_BASE_SIZE = 12

-- { wmName, gameFont, sizeOffset, hasShadow }
-- sizeOffset is relative to the base size (0 = base, -2 = small, +4 = large).
-- hasShadow bakes a drop shadow into the font object itself: a shadow set at
-- runtime on a FontString may not render on current Retail.
local FONT_DEFS = {
  { "WM_Normal", "GameFontNormal", 0 },
  { "WM_DisableSmall", "GameFontDisableSmall", -2 },
  { "WM_Highlight", "GameFontHighlight", 0 },
  { "WM_HighlightSmall", "GameFontHighlightSmall", -2 },
  { "WM_HighlightLarge", "GameFontHighlightLarge", 4 },
  { "WM_ChatNormal", "GameFontHighlight", 0 },
  { "WM_Title", "GameFontHighlight", 0, true },
  -- The "×" close glyph draws far smaller than letters of the same size.
  { "WM_CloseGlyph", "GameFontHighlightLarge", 10 },
}

local SHADOW_OFFSET_X, SHADOW_OFFSET_Y = 1, -1
local SHADOW_ALPHA = 0.85

local FONT_MAP = {
  contact_name = "WM_Normal",
  contact_preview = "WM_DisableSmall",
  contact_time = "WM_DisableSmall",
  message_text = "WM_Highlight",
  message_time = "WM_DisableSmall",
  header_name = "WM_HighlightLarge",
  header_status = "WM_DisableSmall",
  date_separator = "WM_DisableSmall",
  system_text = "WM_HighlightSmall",
  unread_badge = "WM_HighlightSmall",
  composer_input = "WM_ChatNormal",
  icon_label = "WM_Highlight",
  empty_state = "WM_Highlight",
  window_title = "WM_Title",
  close_glyph = "WM_CloseGlyph",
}

local currentMode = "default"
local currentFontPath = nil
local currentFontSize = DEFAULT_BASE_SIZE
local currentOutline = "NONE"
local currentFontColor = "default"
local currentLanguage = "auto"
-- Font the theme preset brings (EllesmereUI's); used under the Default family.
local themeFontPath = nil

local function selectMode(mode)
  local path = FontFamilies.FetchPath(mode)
  if path then
    currentMode = mode
    currentFontPath = path
  else
    currentMode = "default"
    currentFontPath = nil
  end
end

local function resolveOutlineFlags(outline)
  if outline == "OUTLINE" or outline == "THICKOUTLINE" then
    return outline
  end
  return ""
end

local function effectiveLanguage()
  if currentLanguage ~= "auto" and currentLanguage ~= nil then
    return currentLanguage
  end
  local getLocale = _G and _G.GetLocale
  if type(getLocale) == "function" then
    local ok, locale = pcall(getLocale)
    if ok and type(locale) == "string" then
      return locale
    end
  end
  return nil
end

local function clientLocale()
  local getLocale = _G and _G.GetLocale
  if type(getLocale) == "function" then
    local ok, locale = pcall(getLocale)
    if ok and type(locale) == "string" then
      return locale
    end
  end
  return nil
end

local function resolveInheritedSourceFontObject()
  local language = effectiveLanguage()
  if language == nil or not MULTI_SCRIPT_LANGUAGES[language] then
    return nil
  end
  -- When the WoW client's locale matches the addon language, the
  -- locale-specific primary fonts already cover the script natively, so
  -- SetFont with a customized size works without losing any glyphs.
  -- Skip the inheritance override and keep size customization for users
  -- on a matched client.
  if clientLocale() == language then
    return nil
  end
  for _, name in ipairs(MULTI_SCRIPT_FONT_OBJECT_NAMES) do
    local obj = _G[name]
    if obj then
      return obj
    end
  end
  return nil
end

local function applyFonts()
  local baseSize = currentFontSize
  local flags = resolveOutlineFlags(currentOutline)
  local CreateFont = _G.CreateFont
  local inheritedSource = resolveInheritedSourceFontObject()
  -- The theme's font may lack CJK or Cyrillic glyphs: those clients keep the game's locale font.
  local fontPath = currentFontPath
  if fontPath == nil and not MULTI_SCRIPT_LANGUAGES[clientLocale() or ""] then
    fontPath = themeFontPath
  end

  for _, def in ipairs(FONT_DEFS) do
    local wmName, gameFont, sizeOffset, hasShadow = def[1], def[2], def[3], def[4]
    local size = baseSize + sizeOffset
    local fontObj = _G[wmName]
    if not fontObj then
      fontObj = CreateFont(wmName)
    end

    if inheritedSource then
      -- Inherit the multi-script FontFamily chain so the engine can fall
      -- back to a glyph file that covers the locale's script. Calling
      -- SetFont after this would replace the chain with a single path
      -- and we'd be back to squares (CJK) or frozen-size fallback glyphs
      -- (Cyrillic on a non-Russian client).
      fontObj:SetFontObject(inheritedSource)
    elseif fontPath then
      fontObj:SetFont(fontPath, size, flags)
    else
      local source = _G[gameFont]
      if source then
        fontObj:SetFontObject(source)
        local p = source:GetFont()
        fontObj:SetFont(p or FRIZQT_PATH, size, flags)
      else
        fontObj:SetFont(FRIZQT_PATH, size, flags)
      end
    end

    if hasShadow and fontObj.SetShadowOffset then
      fontObj:SetShadowOffset(SHADOW_OFFSET_X, SHADOW_OFFSET_Y)
      fontObj:SetShadowColor(0, 0, 0, SHADOW_ALPHA)
    end

    -- An inherited multi-script chain must stay whole: no chat-font twin then.
    GlyphCoverage.UpdateTwin(wmName, fontObj, size, flags, inheritedSource == nil)
  end
end

function Fonts.Initialize(mode)
  selectMode(mode)
  currentFontSize = DEFAULT_BASE_SIZE
  currentOutline = "NONE"
  currentFontColor = "default"
  currentLanguage = "auto"
  applyFonts()
end

function Fonts.SetLanguage(language)
  currentLanguage = language or "auto"
  applyFonts()
end

function Fonts.GetLanguage()
  return currentLanguage
end

function Fonts.SetMode(mode)
  selectMode(mode)
  applyFonts()
end

function Fonts.GetMode()
  return currentMode
end

-- A chosen font family still wins; nil drops the theme's font.
function Fonts.SetThemeFontPath(path)
  if type(path) ~= "string" or path == "" then
    path = nil
  end
  if path == themeFontPath then
    return
  end
  themeFontPath = path
  applyFonts()
end

Fonts.ListFontFamilies = FontFamilies.List

function Fonts.SetFontSize(size)
  currentFontSize = size or DEFAULT_BASE_SIZE
  applyFonts()
end

function Fonts.GetFontSize()
  return currentFontSize
end

Fonts.DEFAULT_BASE_SIZE = DEFAULT_BASE_SIZE

function Fonts.SetOutline(outline)
  currentOutline = outline or "NONE"
  applyFonts()
end

function Fonts.GetOutline()
  return currentOutline
end

function Fonts.SetFontColor(key)
  if type(key) == "string" and FontColors.Get(key) then
    currentFontColor = key
  else
    currentFontColor = "default"
  end
end

function Fonts.GetFontColorRGBA()
  local preset = FontColors.Get(currentFontColor)
  return preset and preset.rgba or nil
end

Fonts.ListFontColorPresets = FontColors.List

for key, value in pairs(FONT_MAP) do
  Fonts[key] = value
end

ns.ThemeFonts = Fonts
return Fonts
