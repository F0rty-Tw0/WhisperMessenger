local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

-- Notes other addons attach to the open player: a bar under the header,
-- one 22px row per note, in the header's fill. The thread starts below it.
local InfoStrip = {}

local ROW_HEIGHT = 22
-- More notes would crowd the thread out of the window.
local MAX_ROWS = 3
local SIDE_PADDING = 16

local function applyTheme(strip)
  UIHelpers.applyColorTexture(strip.bg, Theme.COLORS.bg_header)
  for _, row in ipairs(strip.rows) do
    UIHelpers.applyColor(row, Theme.COLORS.text_secondary)
  end
end

local function createRow(strip, index)
  local row = strip.frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  local top = -(index - 1) * ROW_HEIGHT
  row:SetPoint("TOPLEFT", strip.frame, "TOPLEFT", SIDE_PADDING, top)
  row:SetPoint("TOPRIGHT", strip.frame, "TOPRIGHT", -SIDE_PADDING, top)
  row:SetHeight(ROW_HEIGHT)
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

  local strip = { frame = frame, bg = bg, rows = {} }
  applyTheme(strip)

  function strip.setLines(lines)
    local count = math.min(#lines, MAX_ROWS)
    for index = 1, count do
      local text = lines[index]
      local row = strip.rows[index]
      if row == nil then
        row = createRow(strip, index)
        strip.rows[index] = row
      end
      row:SetText(text)
      row:Show()
    end
    for index = count + 1, #strip.rows do
      strip.rows[index]:Hide()
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
  local lines = selectedContact and getLines and getLines(selectedContact) or {}
  local before = strip.height()
  strip.setLines(lines)
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
