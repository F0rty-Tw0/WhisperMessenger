local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local GlyphCoverage = ns.ThemeGlyphCoverage or require("WhisperMessenger.UI.Theme.GlyphCoverage")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")

-- How many rows the composer text wraps to, and the bar height they need:
-- the bar is the one-row bar plus one line per extra row.
local ComposerRows = {}

ComposerRows.MAX_ROWS = 2

local DEFAULT_LINE_HEIGHT = 12

-- Two lines wide enough never to wrap.
local PITCH_SAMPLE = "X\nX"
local PITCH_SAMPLE_WIDTH = 1000

function ComposerRows.BarHeight(rows, lineHeight)
  return Theme.COMPOSER_HEIGHT + (rows - 1) * lineHeight
end

-- Rows that fit under maxBarHeight (nil = no limit), 1 to MAX_ROWS.
function ComposerRows.RowCap(maxBarHeight, lineHeight)
  if maxBarHeight == nil then
    return ComposerRows.MAX_ROWS
  end
  local fitting = 1 + math.floor((maxBarHeight - Theme.COMPOSER_HEIGHT) / lineHeight)

  return math.max(1, math.min(ComposerRows.MAX_ROWS, fitting))
end

-- A hidden word-wrapping FontString on `pane`, set to the composer's font,
-- tells how many lines text takes at a width.
function ComposerRows.Create(pane, font)
  local measurer = pane:CreateFontString(nil, "ARTWORK")
  measurer:SetWordWrap(true)
  measurer:Hide()
  GlyphCoverage.SetInputFont(measurer, font)

  local rows = { measurer = measurer }

  -- The pitch the game lays lines out at, measured on two sample lines: it
  -- can sit under the font size (10.67 px for 11 px text on Retail), and a
  -- font-size viewport then shows a sliver of the line scrolled out above.
  -- The font size when the measurer can't tell; DEFAULT_LINE_HEIGHT until
  -- the font object is built.
  function rows.lineHeight()
    local inputFont = GlyphCoverage.InputFont(font)
    local hasGetFont = type(inputFont) == "table" and type(inputFont.GetFont) == "function"
    if not hasGetFont then
      return DEFAULT_LINE_HEIGHT
    end
    local _, size = inputFont:GetFont()
    size = size or DEFAULT_LINE_HEIGHT
    measurer:SetWidth(PITCH_SAMPLE_WIDTH)
    measurer:SetText(PITCH_SAMPLE)
    local height, lines = measurer:GetStringHeight(), measurer:GetNumLines()
    if type(height) ~= "number" or height <= 0 or type(lines) ~= "number" or lines <= 0 then
      return size
    end

    return height / lines
  end

  function rows.count(text, width)
    measurer:SetWidth(width)
    measurer:SetText(text)
    GlyphCoverage.UpdateInput(measurer)

    return math.max(1, measurer:GetNumLines())
  end

  -- Rows to show (capped by maxBarHeight) and the bar height they need. count
  -- runs first: it puts the measurer on the font the text needs, and the
  -- pitch is then measured on that font.
  function rows.fit(text, width, maxBarHeight)
    local count = 1
    local wrapped = text ~= nil and rows.count(text, width)
    local lineHeight = rows.lineHeight()
    if wrapped then
      count = math.min(wrapped, ComposerRows.RowCap(maxBarHeight, lineHeight))
    end

    return count, ComposerRows.BarHeight(count, lineHeight)
  end

  return rows
end

ns.ComposerRows = ComposerRows
return ComposerRows
