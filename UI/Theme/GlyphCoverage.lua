local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

-- WoW's default UI font (Friz Quadrata) has no "ő", "ű" or most other Latin
-- Extended letters (Hungarian, Polish, Czech, ...): they draw as squares.
-- Each WM_ font object on that font gets a twin on the game's chat font
-- (Arial Narrow, what Blizzard's own chat frame uses) with the same size,
-- outline, shadow and colour. Apply moves a FontString to the twin while its
-- text needs one of those letters, and back when it no longer does. Text
-- boxes (EditBoxes) keep their base font object and switch only the font
-- file, with SetFont, to the chat font while their text holds one of those
-- letters (UpdateInput), and back when it no longer does.
local GlyphCoverage = {}

-- A twin stays paired with its base for good, so a widget left on the twin
-- always finds its way back. inUse[base] says whether the twin is wanted now.
local twinOf = {}
local baseOf = {}
local inUse = {}

-- UTF-8 lead bytes 0xC4-0xC9: U+0100-U+027F, Latin Extended-A and -B.
local EXTENDED_LATIN_PATTERN = "[\196-\201][\128-\191]"
local CHAT_FONT_LEAD_PATTERN = "[\196-\244]"
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

-- True when text holds a letter from U+0100 up (UTF-8 lead bytes 0xC4-0xF4):
-- Latin Extended, Cyrillic, Greek, ... none of them are in Friz Quadrata.
function GlyphCoverage.NeedsChatFont(text)
  if type(text) ~= "string" or SecretValue.Is(text) then
    return false
  end
  return string.find(text, CHAT_FONT_LEAD_PATTERN) ~= nil
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

-- Text boxes (box -> record): face() answers the path, size and flags the box
-- shows when its text needs no chat font; shown is the path last set; base is
-- the box's font object (ours only), kept because a live EditBox answers nil
-- to GetFontObject.
local inputs = setmetatable({}, { __mode = "k" })

-- Refreshes base's twin ("<baseName>_Wide") after base changed. allowed is
-- false when base must keep its own font chain (another script's language):
-- the twin then just mirrors base. The twin is made the first time base
-- sits on a font without those letters; until then inUse[base] is nil and
-- text boxes keep base's own file.
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

-- The font object to read a text box's size from: font's twin while base is
-- on a font lacking those letters, else font. The twin has base's size, so
-- ComposerRows only takes the size from it. font is a font object or its name.
function GlyphCoverage.InputFont(font)
  local base = _G[font] or font
  return inUse[base] and twinOf[base] or base
end

-- Re-reads box's text and puts it on the right font file. force sets the file
-- even when it is the one set last (after a font object swap reset it).
function GlyphCoverage.UpdateInput(box, force)
  local record = inputs[box]
  if record == nil or type(box.GetText) ~= "function" or type(box.SetFont) ~= "function" then
    return
  end
  -- Base not on a font lacking those letters (another script's font chain,
  -- or not built yet): the box keeps the font object swapFont gave it.
  if record.base ~= nil and inUse[record.base] ~= true then
    return
  end
  local path, size, flags = record.face()
  if GlyphCoverage.NeedsChatFont(box:GetText()) and GlyphCoverage.LacksExtendedLatin(path) then
    path = chatFontPath()
  end
  if force or path ~= record.shown then
    box:SetFont(path, size, flags or "")
    record.shown = path
  end
end

-- Puts box on font and, while font is on a font lacking those letters, on the
-- chat font file whenever its text needs it. font is a font object or its name.
function GlyphCoverage.SetInputFont(box, font)
  if type(box) ~= "table" or type(box.SetFontObject) ~= "function" then
    return
  end
  local base = _G[font] or font
  swapFont(box, base)
  inputs[box] = {
    base = base,
    face = function()
      return base:GetFont()
    end,
  }
  GlyphCoverage.UpdateInput(box, true)
end

-- For a game-made text box with its own font (the contacts search): its face
-- now is the one to use until its text needs the chat font. Once only. A box
-- whose font already has those letters (another script's font) is left alone:
-- SetFont would replace its multi-script font chain with one file.
function GlyphCoverage.SetGameInputFont(box)
  if type(box) ~= "table" or inputs[box] ~= nil or type(box.GetFont) ~= "function" then
    return
  end
  local path, size, flags = box:GetFont()
  if type(path) ~= "string" or not GlyphCoverage.LacksExtendedLatin(path) then
    return
  end
  inputs[box] = {
    face = function()
      return path, size, flags
    end,
  }
  GlyphCoverage.UpdateInput(box, true)
end

-- Puts every text box back on its font after the fonts were rebuilt.
function GlyphCoverage.RefreshInputs()
  for box, record in pairs(inputs) do
    if record.base ~= nil then
      swapFont(box, record.base)
    end
    GlyphCoverage.UpdateInput(box, true)
  end
end

-- For a game-made text box (a Blizzard template): moves it to the chat font
-- at its own size when its font lacks those letters. Only the font file
-- changes, never the font object. Returns what it had, for RestoreFace, or
-- nil when nothing changed.
function GlyphCoverage.UseChatFace(box)
  if type(box) ~= "table" or type(box.GetFont) ~= "function" or type(box.SetFont) ~= "function" then
    return nil
  end
  local path, size, flags = box:GetFont()
  if not GlyphCoverage.LacksExtendedLatin(path) then
    return nil
  end
  box:SetFont(chatFontPath(), size, flags or "")
  return { path, size, flags or "" }
end

function GlyphCoverage.RestoreFace(box, saved)
  if type(saved) ~= "table" or type(box) ~= "table" or type(box.SetFont) ~= "function" then
    return
  end
  box:SetFont(saved[1], saved[2], saved[3])
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
