local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Hyperlinks = ns.UIHyperlinks or require("WhisperMessenger.UI.Hyperlinks")

-- Notes other addons attach to the open player: a bar under the header,
-- one 22px row per note, in the header's fill. The thread starts below it.
-- Each row is its own mouse frame holding its text, so item links in the
-- note and the note's own tooltip both work on it: a link's tooltip wins
-- while the cursor is on the link.
local InfoStrip = {}

local ROW_HEIGHT = 22
-- More notes would crowd the thread out of the window.
local MAX_ROWS = 3
local SIDE_PADDING = 16
-- The game's wrap width squeezes a long match explanation into a tall column.
local TOOLTIP_MIN_WIDTH = 400

local function applyTheme(strip)
  UIHelpers.applyColorTexture(strip.bg, Theme.COLORS.bg_header)
  for _, row in ipairs(strip.rows) do
    UIHelpers.applyColor(row, Theme.COLORS.text_secondary)
  end
end

-- The shared tooltip keeps a minimum width until someone resets it, so the
-- row hands it back at 0 before a link or another frame uses it.
local function setTooltipMinWidth(width)
  local tooltip = _G.GameTooltip
  if tooltip and type(tooltip.SetMinimumWidth) == "function" then
    tooltip:SetMinimumWidth(width)
  end
end

local function hideRowTooltip()
  setTooltipMinWidth(0)
  Hyperlinks.HandleLeave()
end

local function showRowTooltip(rowFrame)
  local lines = rowFrame.tooltipLines
  local tooltip = _G.GameTooltip
  if lines == nil or tooltip == nil or type(tooltip.SetOwner) ~= "function" then
    return
  end
  tooltip:SetOwner(rowFrame, "ANCHOR_BOTTOM")
  setTooltipMinWidth(TOOLTIP_MIN_WIDTH)
  for _, line in ipairs(lines) do
    -- Wrapped (5th argument) so a long line is not one very wide tooltip.
    pcall(tooltip.AddLine, tooltip, line, 1, 1, 1, true)
  end
  tooltip:Show()
end

-- True when the shared tooltip is showing for this row (its note or a link in it).
-- Nil when the tooltip cannot say, so callers keep their old behavior.
local function ownsTooltip(rowFrame)
  local tooltip = _G.GameTooltip
  if tooltip == nil or type(tooltip.IsOwned) ~= "function" then
    return nil
  end

  return tooltip:IsOwned(rowFrame) and true or false
end

local function sameLines(a, b)
  if a == nil or b == nil then
    return a == b
  end
  if #a ~= #b then
    return false
  end
  for index, line in ipairs(a) do
    if b[index] ~= line then
      return false
    end
  end

  return true
end

-- The row's note changed or the row went away: keep the tooltip it owns true to it.
-- A link under the cursor keeps its item tooltip; the row's comes back on leaving the link.
local function refreshOwnedTooltip(rowFrame)
  if not ownsTooltip(rowFrame) then
    return
  end
  if rowFrame.linkHovered and rowFrame:IsShown() then
    return
  end
  if rowFrame.tooltipLines ~= nil and rowFrame:IsShown() then
    showRowTooltip(rowFrame)
  else
    hideRowTooltip()
  end
end

-- The row's mouse frame: its tooltip on hover, links as in the transcript.
-- Leaving a link while still on the row brings the row's tooltip back.
local function createRowFrame(factory, strip, index)
  local rowFrame = factory.CreateFrame("Frame", nil, strip.frame)
  local top = -(index - 1) * ROW_HEIGHT
  rowFrame:SetPoint("TOPLEFT", strip.frame, "TOPLEFT", 0, top)
  rowFrame:SetPoint("TOPRIGHT", strip.frame, "TOPRIGHT", 0, top)
  rowFrame:SetHeight(ROW_HEIGHT)
  Hyperlinks.EnableOn(rowFrame)
  local hovered = false
  rowFrame:SetScript("OnEnter", function(self)
    hovered = true
    showRowTooltip(self)
  end)
  local enterLink = rowFrame:GetScript("OnHyperlinkEnter")
  rowFrame:SetScript("OnHyperlinkEnter", function(self, ...)
    self.linkHovered = true
    -- The item tooltip keeps the game's own width.
    setTooltipMinWidth(0)
    enterLink(self, ...)
  end)
  rowFrame:SetScript("OnLeave", function(self)
    hovered = false
    self.linkHovered = false
    -- Another frame's tooltip is not ours to hide.
    if ownsTooltip(self) ~= false then
      hideRowTooltip()
    end
  end)
  rowFrame:SetScript("OnHyperlinkLeave", function(self)
    self.linkHovered = false
    hideRowTooltip()
    if hovered then
      showRowTooltip(self)
    end
  end)
  return rowFrame
end

local function createRow(rowFrame)
  local row = rowFrame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  row:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", SIDE_PADDING, 0)
  row:SetPoint("BOTTOMRIGHT", rowFrame, "BOTTOMRIGHT", -SIDE_PADDING, 0)
  row:SetJustifyH("LEFT")
  row:SetJustifyV("MIDDLE")
  row:SetWordWrap(false)
  row:SetMaxLines(1)
  UIHelpers.applyColor(row, Theme.COLORS.text_secondary)
  return row
end

function InfoStrip.Create(factory, pane, headerFrame)
  local frame = factory.CreateFrame("Frame", nil, pane)
  frame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
  frame:SetPoint("TOPRIGHT", headerFrame, "BOTTOMRIGHT", 0, 0)
  frame:Hide()

  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(frame)

  -- rows[i] is the FontString, rowFrames[i] the mouse frame that holds it.
  local strip = { frame = frame, bg = bg, rows = {}, rowFrames = {} }
  applyTheme(strip)

  -- tooltips[i], when given, holds row i's tooltip lines (nil: none).
  function strip.setLines(lines, tooltips)
    local count = math.min(#lines, MAX_ROWS)
    for index = 1, count do
      local rowFrame = strip.rowFrames[index]
      if rowFrame == nil then
        rowFrame = createRowFrame(factory, strip, index)
        strip.rowFrames[index] = rowFrame
        strip.rows[index] = createRow(rowFrame)
      end
      strip.rows[index]:SetText(lines[index])
      local before = rowFrame.tooltipLines
      rowFrame.tooltipLines = tooltips and tooltips[index] or nil
      rowFrame:Show()
      if not sameLines(before, rowFrame.tooltipLines) then
        refreshOwnedTooltip(rowFrame)
      end
    end
    for index = count + 1, #strip.rowFrames do
      strip.rowFrames[index]:Hide()
      refreshOwnedTooltip(strip.rowFrames[index])
    end
    frame:SetHeight(ROW_HEIGHT * count)
    if count > 0 then
      frame:Show()
    else
      frame:Hide()
    end
  end

  function strip.height()
    if not frame:IsShown() then
      return 0
    end
    return frame:GetHeight()
  end

  strip.refreshTheme = function()
    applyTheme(strip)
  end

  return strip
end

-- Height the strip takes from the thread, 0 when the pane has none.
function InfoStrip.HeightOf(view)
  return view.infoStrip and view.infoStrip.height() or 0
end

-- Shows the notes for the selected contact and hangs the thread below the
-- strip while it shows. Returns true when the strip's height changed, so
-- the caller re-lays out the thread.
function InfoStrip.Apply(view, selectedContact)
  local strip = view.infoStrip
  if strip == nil then
    return false
  end

  local getLines = view._getContactInfoLines
  local lines, tooltips
  if selectedContact and getLines then
    lines, tooltips = getLines(selectedContact)
  end
  local before = strip.height()
  strip.setLines(lines or {}, tooltips)
  local after = strip.height()

  if (before > 0) ~= (after > 0) then
    local anchor = after > 0 and strip.frame or view.headerFrame
    local scrollFrame = view.transcript.scrollFrame
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER, 0)
  end
  return before ~= after
end

ns.ConversationPaneInfoStrip = InfoStrip
return InfoStrip
