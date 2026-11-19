local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local ComposerLayout = ns.ComposerLayout or require("WhisperMessenger.UI.Composer.ComposerLayout")
local GlyphCoverage = ns.ThemeGlyphCoverage or require("WhisperMessenger.UI.Theme.GlyphCoverage")

local sizeValue = UIHelpers.sizeValue

-- Composer rows and widths: fits the text rows on the box's text width and
-- lays every part out for the current width and button count.
local ComposerRelayout = {}

-- deps: { parent, pane, parts, rows, input, multiLine, onHeightChanged,
-- getButtonCount }. getButtonCount() is read on every layout (no getter =
-- the full row).
function ComposerRelayout.Create(deps)
  local parent, parts, rows, input = deps.parent, deps.parts, deps.rows, deps.input

  local function getButtonCount()
    if not deps.getButtonCount then
      return nil
    end

    return deps.getButtonCount()
  end

  local function currentParentWidth(fallback)
    local width = sizeValue(parent, "GetWidth", "width", fallback)
    if type(width) ~= "number" or width <= 0 then
      return fallback
    end

    return width
  end

  -- Rows follow the text (a client without the template keeps one row); the
  -- window hears of a new bar height only when it changes.
  local layoutWidth = sizeValue(parent, "GetWidth", "width", 600)
  local maxHeight = nil
  local reportedHeight = Theme.COMPOSER_HEIGHT
  ComposerLayout.Apply(parts, layoutWidth, 1, rows.lineHeight(), getButtonCount())

  local function refresh()
    GlyphCoverage.UpdateInput(input)
    local text
    if deps.multiLine then
      text = input:GetText() or ""
    end
    local buttonCount = getButtonCount()
    local count, height = rows.fit(text, ComposerLayout.TextWidth(layoutWidth, buttonCount), maxHeight)
    ComposerLayout.Apply(parts, layoutWidth, count, rows.lineHeight(), buttonCount)
    if height == reportedHeight then
      return
    end
    reportedHeight = height
    if deps.onHeightChanged then
      deps.onHeightChanged(height)
    end
  end
  -- A hook: SetScript here would drop the OnShow hook send focus put on the pane.
  deps.pane:HookScript("OnShow", refresh)

  -- maxBarHeight caps the rows (nil = up to two).
  local function resize(parentW, maxBarHeight)
    -- Prefer the pane's live width over the passed-in hint: the caller
    -- passes the full content width, but composerPane has a right-margin
    -- anchor (-20 in fake_ui, -8 in production WoW) that makes the pane
    -- narrower. Using the hint would overflow the right padding.
    local effectiveW = currentParentWidth(parentW)
    if type(effectiveW) ~= "number" or effectiveW <= 0 then
      return
    end
    layoutWidth, maxHeight = effectiveW, maxBarHeight
    refresh()
  end

  -- Re-read the pane's width, then refit (a theme change can move the pane).
  local function refreshWidth()
    layoutWidth = currentParentWidth(layoutWidth)
    refresh()
  end

  local function getHeight()
    return reportedHeight
  end

  local relayout = {
    refresh = refresh,
    resize = resize,
    refreshWidth = refreshWidth,
    getHeight = getHeight,
  }

  return relayout
end

ns.ComposerRelayout = ComposerRelayout
return ComposerRelayout
