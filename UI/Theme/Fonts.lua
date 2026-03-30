local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Fonts = {}

local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"
local SYSTEM_FONT_PATH = "Fonts\\ARIALN.TTF"

-- Font object definitions: { wmName, sourceGameFont, size }
local FONT_DEFS = {
  { "WM_Normal", "GameFontNormal", 12 },
  { "WM_DisableSmall", "GameFontDisableSmall", 10 },
  { "WM_Highlight", "GameFontHighlight", 12 },
  { "WM_HighlightSmall", "GameFontHighlightSmall", 10 },
  { "WM_HighlightLarge", "GameFontHighlightLarge", 16 },
  { "WM_ChatNormal", "ChatFontNormal", 14 },
}

-- Semantic font mapping -> WM_ object names
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

local currentMode = "default"

local function applyMode(mode)
  local CreateFont = _G.CreateFont
  for _, def in ipairs(FONT_DEFS) do
    local wmName, sourceGameFont, size = def[1], def[2], def[3]
    local fontObj = _G[wmName]
    if not fontObj then
      fontObj = CreateFont(wmName)
    end

    if mode == "default" then
      fontObj:SetFont(DEFAULT_FONT_PATH, size, "")
    elseif mode == "system" then
      fontObj:SetFont(SYSTEM_FONT_PATH, size, "")
    elseif mode == "custom" then
      local source = _G[sourceGameFont]
      if source and source.GetFont then
        local path, _, flags = source:GetFont()
        fontObj:SetFont(path or DEFAULT_FONT_PATH, size, flags or "")
      else
        fontObj:SetFont(DEFAULT_FONT_PATH, size, "")
      end
    end
  end
  currentMode = mode
end

function Fonts.Initialize(mode)
  applyMode(mode or "default")
  initialized = true
end

function Fonts.SetMode(mode)
  applyMode(mode or "default")
end

function Fonts.GetMode()
  return currentMode
end

function Fonts.GetFonts()
  return FONT_MAP
end

-- Backward compatibility: expose font keys directly on the module table
for key, value in pairs(FONT_MAP) do
  Fonts[key] = value
end

ns.ThemeFonts = Fonts
return Fonts
