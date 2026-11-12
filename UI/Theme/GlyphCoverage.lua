local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

-- WoW's default UI font (Friz Quadrata) has no "ő", "ű" or most other Latin
-- Extended letters (Hungarian, Polish, Czech, ...): they draw as squares.
-- Each WM_ font object on that font gets a twin on the game's chat font
-- (Arial Narrow, what Blizzard's own chat frame uses) with the same size,
-- outline, shadow and colour. Apply moves a FontString or EditBox to the twin
-- while its text needs one of those letters, and back when it no longer does.
local GlyphCoverage = {}

-- A twin stays paired with its base for good, so a widget left on the twin
-- always finds its way back. inUse[base] says whether the twin is wanted now.
local twinOf = {}
local baseOf = {}
local inUse = {}

-- UTF-8 lead bytes 0xC4-0xC9: U+0100-U+027F, Latin Extended-A and -B.
local EXTENDED_LATIN_PATTERN = "[\196-\201][\128-\191]"
local FRIZ_QUADRATA_FILE = "frizqt__"
local CHAT_FONT_PATH = "Fonts\\ARIALN.TTF"
local TWIN_SUFFIX = "_Wide"

function GlyphCoverage.NeedsExtendedLatin(text)
  if type(text) ~= "string" or SecretValue.Is(text) then
    return false
  end
  return string.find(text, EXTENDED_LATIN_PATTERN) ~= nil
end

-- True for a font file known to lack Latin Extended letters.
function GlyphCoverage.LacksExtendedLatin(path)
  if type(path) ~= "string" then
    return false
  end
  return string.find(string.lower(path), FRIZ_QUADRATA_FILE, 1, true) ~= nil
end

function GlyphCoverage.TwinOf(base)
  return twinOf[base]
end

-- The game's chat font, which carries those letters.
local function chatFontPath()
  local chatFont = _G.ChatFontNormal
  if chatFont and type(chatFont.GetFont) == "function" then
    local path = chatFont:GetFont()
    if type(path) == "string" and path ~= "" and not GlyphCoverage.LacksExtendedLatin(path) then
      return path
    end
  end
  return CHAT_FONT_PATH
end

-- Refreshes base's twin ("<baseName>_Wide") after base changed. allowed is
-- false when base must keep its own font chain (another script's language):
-- the twin then just mirrors base. The twin is made the first time base
-- sits on a font without those letters.
function GlyphCoverage.UpdateTwin(baseName, base, size, flags, allowed)
  local wanted = allowed ~= false and type(base.GetFont) == "function" and GlyphCoverage.LacksExtendedLatin(base:GetFont())
  local twin = twinOf[base]
  if twin == nil then
    if not wanted or type(_G.CreateFont) ~= "function" then
      return nil
    end
    local twinName = baseName .. TWIN_SUFFIX
    twin = _G[twinName] or _G.CreateFont(twinName)
    twinOf[base] = twin
    baseOf[twin] = base
  end
  -- Shadow and colour come from base, as base's come from the game's font.
  twin:SetFontObject(base)
  if wanted then
    twin:SetFont(chatFontPath(), size, flags)
  end
  inUse[base] = wanted
  return twin
end

-- SetFontObject may reset the text colour to the font's; keep the widget's.
local function swapFont(widget, font)
  local r, g, b, a
  if type(widget.GetTextColor) == "function" then
    r, g, b, a = widget:GetTextColor()
  end
  widget:SetFontObject(font)
  if r ~= nil and type(widget.SetTextColor) == "function" then
    widget:SetTextColor(r, g, b, a)
  end
end

-- Points widget at the twin when text needs it, else at the base font.
-- Returns text, so a call can wrap the text it is about to show.
function GlyphCoverage.Apply(widget, text)
  if type(widget) ~= "table" or type(widget.GetFontObject) ~= "function" or type(widget.SetFontObject) ~= "function" then
    return text
  end
  local current = widget:GetFontObject()
  if current == nil then
    return text
  end
  local base = baseOf[current] or current
  local target = base
  if inUse[base] and GlyphCoverage.NeedsExtendedLatin(text) then
    target = twinOf[base]
  end
  if target ~= current then
    swapFont(widget, target)
  end
  return text
end

ns.ThemeGlyphCoverage = GlyphCoverage
return GlyphCoverage
