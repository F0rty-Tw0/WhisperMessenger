local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local HoverFade = ns.UIHelpersHoverFade or require("WhisperMessenger.UI.Helpers.HoverFade")

-- Row selection and hover are drawn as overlays: selection is an accent
-- fade from the left edge to transparent; hover is a flat faint white that
-- fades in/out.
local RowHoverOverlay = {}

local function createFill(row)
  local fill = row:CreateTexture(nil, "BACKGROUND", nil, 1)
  fill:SetAllPoints()
  fill:Hide()
  return fill
end

-- Create the overlays once per pooled row; recolor on every bind.
function RowHoverOverlay.ensure(row)
  if row.hoverFill == nil then
    row.selectionFill = createFill(row)
    row.hoverFill = createFill(row)
    row.hoverFade = HoverFade.Attach(row.hoverFill)
  end
  UIHelpers.applyHorizontalFade(row.selectionFill, Theme.COLORS.bg_contact_selected)
  -- Flat on purpose (no gradient on a faded texture); HoverFade keeps the
  -- colour at full alpha and fades 0 <-> the token's alpha.
  row.hoverFade.paintColor(Theme.COLORS.bg_contact_hover)
end

-- Returns true when the overlay owns the hover visual, so the caller must
-- not paint hover into row.bg.
function RowHoverOverlay.update(row, hovered)
  if row.hoverFade == nil then
    return false
  end
  row.selectionFill:SetShown(row.selected == true)
  row.hoverFade.set(hovered and not row.selected)
  return true
end

ns.ContactsListRowHoverOverlay = RowHoverOverlay
return RowHoverOverlay
