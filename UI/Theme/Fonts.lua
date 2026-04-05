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

local function resolveOutlineFlags(outline)
  if outline == "OUTLINE" or outline == "THICKOUTLINE" then
    return outline
  end
  return ""
end

local function applyFonts()
  local mode = currentMode
  local baseSize = currentFontSize
  local flags = resolveOutlineFlags(currentOutline)
  local CreateFont = _G.CreateFont

  for _, def in ipairs(FONT_DEFS) do
    local wmName, gameFont, sizeOffset = def[1], def[2], def[3]
    local size = baseSize + sizeOffset
    local fontObj = _G[wmName]
    if not fontObj then
      fontObj = CreateFont(wmName)
    end

    if mode == "system" then
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
  applyFonts()
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
