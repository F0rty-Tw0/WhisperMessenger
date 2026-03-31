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

-- { wmName, gameFont, size }
local FONT_DEFS = {
  { "WM_Normal", "GameFontNormal", 12 },
  { "WM_DisableSmall", "GameFontDisableSmall", 10 },
  { "WM_Highlight", "GameFontHighlight", 12 },
  { "WM_HighlightSmall", "GameFontHighlightSmall", 10 },
  { "WM_HighlightLarge", "GameFontHighlightLarge", 16 },
  { "WM_ChatNormal", "ChatFontNormal", 12 },
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

local currentMode = "default"

local function applyMode(mode)
  local CreateFont = _G.CreateFont
  for _, def in ipairs(FONT_DEFS) do
    local wmName, gameFont, size = def[1], def[2], def[3]
    local fontObj = _G[wmName]
    if not fontObj then
      fontObj = CreateFont(wmName)
    end

    if mode == "system" then
      fontObj:SetFont(ARIALN_PATH, size, "")
    else
      local source = _G[gameFont]
      if source then
        fontObj:SetFontObject(source)
        local p, _, flags = source:GetFont()
        fontObj:SetFont(p or FRIZQT_PATH, size, flags or "")
      else
        fontObj:SetFont(FRIZQT_PATH, size, "")
      end
    end
  end
  currentMode = mode
end

function Fonts.Initialize(mode)
  applyMode(mode or "default")
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

for key, value in pairs(FONT_MAP) do
  Fonts[key] = value
end

ns.ThemeFonts = Fonts
return Fonts
