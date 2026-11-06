local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- WoW's default UI font (Friz Quadrata) has no "ő", "ű" or most other
-- Latin Extended letters (Hungarian, Polish, Czech, ...): they draw as
-- squares. Each WM_ font object built on that font gets a twin on the
-- game's chat font (Arial Narrow, what Blizzard's own chat frame uses), same
-- size and outline. Apply swaps a FontString or EditBox to the twin while
-- its text needs one of those letters, and back when it no longer does, so
-- every other line keeps the usual look.
local GlyphCoverage = {}

local twinOf = {}
local baseOf = {}

-- UTF-8 lead bytes 0xC4-0xC9: U+0100-U+024F, Latin Extended-A and -B.
local EXTENDED_LATIN_PATTERN = "[\196-\201][\128-\191]"

function GlyphCoverage.NeedsExtendedLatin(text)
  return type(text) == "string" and string.find(text, EXTENDED_LATIN_PATTERN) ~= nil
end

-- True for a font file known to lack Latin Extended letters.
function GlyphCoverage.LacksExtendedLatin(path)
  if type(path) ~= "string" then
    return false
  end
  return string.find(string.lower(path), "frizqt__", 1, true) ~= nil
end

-- twin nil forgets the pair (the base font covers those letters itself).
function GlyphCoverage.Register(base, twin)
  if base == nil then
    return
  end
  local previous = twinOf[base]
  if previous ~= nil then
    baseOf[previous] = nil
  end
  twinOf[base] = twin
  if twin ~= nil then
    baseOf[twin] = base
  end
end

function GlyphCoverage.TwinOf(base)
  return twinOf[base]
end

local ARIALN_PATH = "Fonts\\ARIALN.TTF"
local TWIN_SUFFIX = "_Wide"

-- The game's chat font, which carries those letters.
local function chatFontPath()
  local chatFont = _G.ChatFontNormal
  if chatFont and type(chatFont.GetFont) == "function" then
    local path = chatFont:GetFont()
    if type(path) == "string" and path ~= "" and not GlyphCoverage.LacksExtendedLatin(path) then
      return path
    end
  end
  return ARIALN_PATH
end

-- Builds or refreshes base's twin ("<name>_Wide") when base sits on a font
-- without those letters; otherwise forgets any twin. shadow: nil or
-- { offsetX, offsetY, alpha }.
function GlyphCoverage.UpdateTwin(baseName, base, size, flags, shadow)
  local path = type(base.GetFont) == "function" and base:GetFont() or nil
  if not GlyphCoverage.LacksExtendedLatin(path) or type(_G.CreateFont) ~= "function" then
    GlyphCoverage.Register(base, nil)
    return nil
  end
  local twinName = baseName .. TWIN_SUFFIX
  local twin = _G[twinName] or _G.CreateFont(twinName)
  twin:SetFont(chatFontPath(), size, flags)
  if shadow and twin.SetShadowOffset then
    twin:SetShadowOffset(shadow[1], shadow[2])
    twin:SetShadowColor(0, 0, 0, shadow[3])
  end
  GlyphCoverage.Register(base, twin)
  return twin
end

-- Points widget at the twin font when text needs it, else at the base.
function GlyphCoverage.Apply(widget, text)
  if type(widget) ~= "table" or type(widget.GetFontObject) ~= "function" or type(widget.SetFontObject) ~= "function" then
    return
  end
  local current = widget:GetFontObject()
  if current == nil then
    return
  end
  local base = baseOf[current] or current
  local target = base
  if twinOf[base] ~= nil and GlyphCoverage.NeedsExtendedLatin(text) then
    target = twinOf[base]
  end
  if target ~= current then
    widget:SetFontObject(target)
  end
end

ns.ThemeGlyphCoverage = GlyphCoverage
return GlyphCoverage
