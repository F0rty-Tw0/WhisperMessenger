local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")

local RowTextAnchors = {}

local NAME_LABEL_LEFT_INSET = 10

-- spread: px the name moves up and the preview moves down, so taller rows
-- (bigger fonts) open room for the zone line between them.
function RowTextAnchors.anchorName(label, iconFrame, spread)
  label:ClearAllPoints()
  label:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", NAME_LABEL_LEFT_INSET, Theme.LAYOUT.CONTACT_NAME_OFFSET_Y + spread)
end

function RowTextAnchors.anchorPreview(label, iconFrame, spread)
  label:ClearAllPoints()
  label:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMRIGHT", NAME_LABEL_LEFT_INSET, Theme.LAYOUT.CONTACT_PREVIEW_OFFSET_Y - spread)
end

function RowTextAnchors.anchorTextLines(row, rowHeight)
  local spread = (rowHeight - Theme.LAYOUT.CONTACT_ROW_HEIGHT) / 2
  if row.title then
    RowTextAnchors.anchorName(row.title, row.classIconFrame, spread)
  end
  if row.preview then
    RowTextAnchors.anchorPreview(row.preview, row.classIconFrame, spread)
  end
end

RowTextAnchors.NAME_LABEL_LEFT_INSET = NAME_LABEL_LEFT_INSET

ns.ContactsListRowTextAnchors = RowTextAnchors
return RowTextAnchors
