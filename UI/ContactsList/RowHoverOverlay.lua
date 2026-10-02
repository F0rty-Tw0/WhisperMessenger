local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local HoverFade = ns.UIHelpersHoverFade or require("WhisperMessenger.UI.Helpers.HoverFade")
local HoverPointer = ns.ContactsListHoverPointer or require("WhisperMessenger.UI.ContactsList.HoverPointer")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local NativeArt = ns.UIHelpersNativeArt or require("WhisperMessenger.UI.Helpers.NativeArt")
local applyColorTexture = UIHelpers.applyColorTexture
local isPointerInsideRowFrames = HoverPointer.isPointerInsideRowFrames

-- Row selection and hover are drawn as overlays: selection is an accent
-- fade from the left edge to transparent; hover is a flat faint white that
-- fades in/out. Under the Native WoW HUD both are Blizzard list highlight
-- art (the quest log's selected entry, the dropdown menu's hover) tinted
-- with the preset's colours.
local RowHoverOverlay = {}

local function createFill(row)
  local fill = row:CreateTexture(nil, "BACKGROUND", nil, 1)
  fill:SetAllPoints()
  fill:Hide()
  return fill
end

local function createOverlays(row)
  row.selectionFill = createFill(row)
  row.hoverFill = createFill(row)
  if Hud.IsOn() then
    NativeArt.AttachList(row.selectionFill, row.hoverFill)
  end
  row.hoverFade = HoverFade.Attach(row.hoverFill)
end

-- Create the overlays once per pooled row; recolor on every bind.
function RowHoverOverlay.ensure(row)
  if row.hoverFill == nil then
    createOverlays(row)
  end
  if Hud.IsOn() then
    NativeArt.TintList(row.selectionFill, row.hoverFade, Theme.COLORS)
    return
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

local CLEAR = { 0, 0, 0, 0 }

local function isHovered(row)
  return row._wmRowHover == true
    or (row._wmActionHoverCount or 0) > 0
    or ((row._wmIsPointerInside and row._wmIsPointerInside()) or isPointerInsideRowFrames(row))
end

-- The one painter for a row's selection, hover and base look. Row hover
-- scripts, the action buttons and SetSelected all repaint through it.
function RowHoverOverlay.paint(row)
  local hovered = isHovered(row)
  local overlayOwnsHover = RowHoverOverlay.update(row, hovered)
  if row.bg == nil then
    return
  end
  -- The HUD row stays clear so the template inset shows, like the pane.
  if Hud.IsOn() then
    applyColorTexture(row.bg, CLEAR)
  elseif row.selected and not overlayOwnsHover then
    applyColorTexture(row.bg, Theme.COLORS.bg_contact_selected)
  elseif hovered and not overlayOwnsHover then
    applyColorTexture(row.bg, Theme.COLORS.bg_contact_hover)
  elseif row.item and row.item.pinned then
    applyColorTexture(row.bg, Theme.COLORS.bg_contact_pinned)
  else
    applyColorTexture(row.bg, CLEAR)
  end
end

ns.ContactsListRowHoverOverlay = RowHoverOverlay
return RowHoverOverlay
