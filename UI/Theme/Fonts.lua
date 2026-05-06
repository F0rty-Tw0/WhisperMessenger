local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Fonts = {}

-- WM_ font objects act as stable references that all FontStrings point at.
-- Mode switching calls SetFontObject (for the engine's glyph fallback chain)
-- then SetFont (to propagate the change to every FontString).

local FRIZQT_PATH = "Fonts\\FRIZQT__.TTF"
local ARIALN_PATH = "Fonts\\ARIALN.TTF"
local MORPHEUS_PATH = "Fonts\\MORPHEUS.TTF"

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

-- { wmName, gameFont, sizeOffset }
-- sizeOffset is relative to the base size (0 = base, -2 = small, +4 = large)
local FONT_DEFS = {
  { "WM_Normal", "GameFontNormal", 0 },
  { "WM_DisableSmall", "GameFontDisableSmall", -2 },
  { "WM_Highlight", "GameFontHighlight", 0 },
  { "WM_HighlightSmall", "GameFontHighlightSmall", -2 },
  { "WM_HighlightLarge", "GameFontHighlightLarge", 4 },
  { "WM_ChatNormal", "GameFontHighlight", 0 },
}

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
}

local FONT_COLOR_PRESETS = {
  default = { key = "default", label = "Default", rgba = nil },
  gold = { key = "gold", label = "Gold", rgba = { 1, 0.82, 0, 1 } },
  light_blue = { key = "light_blue", label = "Blue", rgba = { 0.67, 0.85, 1, 1 } },
  soft_green = { key = "soft_green", label = "Green", rgba = { 0.67, 1, 0.67, 1 } },
  purple = { key = "purple", label = "Purple", rgba = { 0.78, 0.61, 1, 1 } },
  rose = { key = "rose", label = "Rose", rgba = { 1, 0.65, 0.75, 1 } },
}

local FONT_COLOR_ORDER = { "default", "gold", "light_blue", "soft_green", "purple", "rose" }

local currentMode = "default"
local currentFontSize = DEFAULT_BASE_SIZE
local currentOutline = "NONE"
local currentFontColor = "default"
local currentLanguage = "auto"

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
  local mode = currentMode
  local baseSize = currentFontSize
  local flags = resolveOutlineFlags(currentOutline)
  local CreateFont = _G.CreateFont
  local inheritedSource = resolveInheritedSourceFontObject()

  for _, def in ipairs(FONT_DEFS) do
    local wmName, gameFont, sizeOffset = def[1], def[2], def[3]
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
    elseif mode == "system" then
      fontObj:SetFont(ARIALN_PATH, size, flags)
    elseif mode == "morpheus" then
      fontObj:SetFont(MORPHEUS_PATH, size, flags)
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
  end
end

function Fonts.Initialize(mode)
  currentMode = mode or "default"
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
  currentMode = mode or "default"
  applyFonts()
end

function Fonts.GetMode()
  return currentMode
end

function Fonts.SetFontSize(size)
  currentFontSize = size or DEFAULT_BASE_SIZE
  applyFonts()
end

function Fonts.GetFontSize()
  return currentFontSize
end

function Fonts.SetOutline(outline)
  currentOutline = outline or "NONE"
  applyFonts()
end

function Fonts.GetOutline()
  return currentOutline
end

function Fonts.SetFontColor(key)
  if type(key) == "string" and FONT_COLOR_PRESETS[key] then
    currentFontColor = key
  else
    currentFontColor = "default"
  end
end

function Fonts.GetFontColor()
  return currentFontColor
end

function Fonts.GetFontColorRGBA()
  local preset = FONT_COLOR_PRESETS[currentFontColor]
  return preset and preset.rgba or nil
end

function Fonts.ListFontColorPresets()
  local list = {}
  for _, key in ipairs(FONT_COLOR_ORDER) do
    local preset = FONT_COLOR_PRESETS[key]
    list[#list + 1] = { key = preset.key, label = preset.label, rgba = preset.rgba }
  end
  return list
end

function Fonts.GetFonts()
  return FONT_MAP
end

for key, value in pairs(FONT_MAP) do
  Fonts[key] = value
end

ns.ThemeFonts = Fonts
return Fonts
