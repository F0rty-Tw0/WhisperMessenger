local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local fitTextWithEllipsis = UIHelpers.fitTextWithEllipsis

-- Fits the header's text rows to the header width: the name row (name,
-- faction icon, addon badge, group chip) and the two status lines. Re-run
-- after a resize, a font change or new header content.
local HeaderFit = {}

local RIGHT_INSET = 8
-- Gap between the name and each region anchored after it.
local NAME_ROW_GAP = 6

local function isShown(region)
  return region ~= nil and type(region.IsShown) == "function" and region:IsShown()
end

-- Regions after the name: framed ones report their box width, the chip
-- (a font string sized to its text) its string width.
local function reservedAfterName(view)
  local reserved = 0
  for _, region in ipairs({ view.headerFactionIcon, view.headerAddonBadgeButton }) do
    if isShown(region) then
      reserved = reserved + NAME_ROW_GAP + (region:GetWidth() or 0)
    end
  end
  local chip = view.headerChannelChip
  if isShown(chip) then
    reserved = reserved + NAME_ROW_GAP + (chip:GetStringWidth() or 0)
  end
  return reserved
end

-- Width left for header text right of the class icon; nil before the first
-- relayout reports a width.
local function textWidth(view)
  if type(view._headerWidth) ~= "number" then
    return nil
  end
  local layout = Theme.LAYOUT
  return math.max(0, view._headerWidth - layout.TRANSCRIPT_LEFT_GUTTER - layout.HEADER_ICON_SIZE - layout.HEADER_NAME_GAP - RIGHT_INSET)
end

local function fitOneLine(fontString, fullText, width)
  fontString:SetWidth(width)
  fontString:SetText(fitTextWithEllipsis(fontString, fullText, width))
end

local function fitStatusLine(fontString, visible, fullText, width)
  if fontString == nil or visible ~= true then
    return
  end
  if width == nil then
    fontString:SetText(fullText or "")
  else
    fitOneLine(fontString, fullText or "", width)
  end
end

function HeaderFit.Status(view)
  if view == nil then
    return
  end
  local width = textWidth(view)
  fitStatusLine(view.headerStatus, view._headerStatusVisible, view._headerStatusFullText, width)
  fitStatusLine(view.headerStatusDetail, view._headerStatusDetailVisible, view._headerStatusDetailFullText, width)
end

-- The name gives up width first so the regions after it stay whole. The
-- client truncates a fixed-width, non-wrapping name with "..." itself, which
-- keeps nickname colour and muted-icon escapes intact.
function HeaderFit.Name(view)
  local name = view and view.headerName
  local width = view and textWidth(view)
  if name == nil or width == nil or not isShown(name) then
    return
  end
  local reserved = reservedAfterName(view)
  -- Width 0 lets the string size to its text so it can be measured whole.
  name:SetWidth(0)
  local natural = math.ceil(name:GetStringWidth() or 0)
  name:SetWidth(math.max(0, math.min(natural, width - reserved)))
end

function HeaderFit.All(view)
  HeaderFit.Name(view)
  HeaderFit.Status(view)
end

ns.ConversationPaneHeaderFit = HeaderFit
return HeaderFit
