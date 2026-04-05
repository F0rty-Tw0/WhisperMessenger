local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture

local ContextMenu = ns.ContactsListContextMenu or require("WhisperMessenger.UI.ContactsList.ContextMenu")
local HoverPointer = ns.ContactsListHoverPointer or require("WhisperMessenger.UI.ContactsList.HoverPointer")
local isPointerInsideRowFrames = HoverPointer.isPointerInsideRowFrames
local effectiveActionHoverCount = HoverPointer.effectiveActionHoverCount

local RowScripts = {}

-- Resolve ActionButtons lazily: RowScripts loads before ActionButtons in the
-- TOC, so ns.ContactsListActionButtons is nil at load time.
local _actionButtons
local function getActionButtons()
  if _actionButtons then
    return _actionButtons
  end
  _actionButtons = ns.ContactsListActionButtons
  if not _actionButtons and type(require) == "function" then
    local ok, mod = pcall(require, "WhisperMessenger.UI.ContactsList.ActionButtons")
    if ok then
      _actionButtons = mod
    end
  end
  return _actionButtons
end

local function isPointerInsideRow(row)
  return isPointerInsideRowFrames(row)
end

--- Schedule hideActions for the next frame so button OnEnter/Row OnEnter
--- can fire first, preventing re-entrant hover events from frame hiding.
local function deferHideActions(row)
  local CTimer = _G.C_Timer
  if CTimer and CTimer.After then
    CTimer.After(0, function()
      local AB = getActionButtons()
      local pointerInside = (row._wmIsPointerInside and row._wmIsPointerInside()) or isPointerInsideRow(row)
      if AB and not pointerInside and effectiveActionHoverCount(row) == 0 then
        row._wmRowHover = false
        row._wmApplyVisualState()
        AB.hideActions(row)
      end
    end)
  else
    local AB = getActionButtons()
    local pointerInside = (row._wmIsPointerInside and row._wmIsPointerInside()) or isPointerInsideRow(row)
    if AB and not pointerInside and effectiveActionHoverCount(row) == 0 then
      row._wmRowHover = false
      row._wmApplyVisualState()
      AB.hideActions(row)
    end
  end
end

local function rowBaseColor(row)
  if row._wmRowBaseBg then
    return row._wmRowBaseBg
  end
  return (row.item and row.item.pinned and Theme.COLORS.bg_contact_pinned) or Theme.COLORS.bg_secondary
end

local function applyRowVisualState(row)
  local hovered = row._wmRowHover == true
    or (row._wmActionHoverCount or 0) > 0
    or ((row._wmIsPointerInside and row._wmIsPointerInside()) or isPointerInsideRow(row))
  if row.selected then
    applyColorTexture(row.bg, Theme.COLORS.bg_contact_selected)
  elseif hovered then
    applyColorTexture(row.bg, Theme.COLORS.bg_contact_hover)
  else
    applyColorTexture(row.bg, rowBaseColor(row))
  end
  if row.selectedRightBorder then
    applyColorTexture(row.selectedRightBorder, Theme.COLORS.contact_selected_border_right or Theme.COLORS.accent_bar)
    if row.selected then
      row.selectedRightBorder:Show()
    else
      row.selectedRightBorder:Hide()
    end
  end
end

local function installHoverWatchdog(row)
  if row._wmHoverWatchdogInstalled then
    return
  end
  row._wmHoverWatchdogInstalled = true
  row._wmHoverWatchdogPreviousOnUpdate = row.GetScript and row:GetScript("OnUpdate") or nil
  row._wmHoverWatchdogElapsed = 0

  if row.SetScript then
    row:SetScript("OnUpdate", function(self, elapsed)
      local previous = self._wmHoverWatchdogPreviousOnUpdate
      if previous then
        previous(self, elapsed)
      end

      self._wmHoverWatchdogElapsed = (self._wmHoverWatchdogElapsed or 0) + (elapsed or 0)
      if self._wmHoverWatchdogElapsed < 0.05 then
        return
      end
      self._wmHoverWatchdogElapsed = 0

      if self.selected then
        return
      end
      local pointerInside = (self._wmIsPointerInside and self._wmIsPointerInside()) or isPointerInsideRow(self)
      if pointerInside then
        return
      end
      local hadHoverState = self._wmRowHover or (self._wmActionHoverCount or 0) > 0
      if not hadHoverState then
        return
      end
      effectiveActionHoverCount(self)

      self._wmRowHover = false
      self._wmActionHoverCount = 0
      if self._wmApplyVisualState then
        self._wmApplyVisualState()
      else
        applyRowVisualState(self)
      end

      local AB = getActionButtons()
      if AB then
        AB.hideActions(self)
      end
    end)
  end
end

--- Bind OnEnter / OnLeave hover scripts to a row.
--- options may include: rowBaseBg (color table for base background)
function RowScripts.bindHover(row, options)
  row._wmRowBaseBg = (options and options.rowBaseBg)
    or (row.item and row.item.pinned and Theme.COLORS.bg_contact_pinned or Theme.COLORS.bg_secondary)
  row._wmRowHover = false
  row._wmActionHoverCount = 0
  row._wmIsPointerInside = function()
    return isPointerInsideRow(row)
  end
  row._wmApplyVisualState = function()
    applyRowVisualState(row)
  end

  row._wmHoverWatchdogElapsed = 0
  installHoverWatchdog(row)

  row._wmApplyVisualState()

  if row.SetScript then
    row:SetScript("OnEnter", function()
      row._wmRowHover = true
      row._wmApplyVisualState()
      local AB = getActionButtons()
      if AB then
        AB.showActions(row)
      end
    end)

    row:SetScript("OnLeave", function()
      row._wmRowHover = false
      row._wmApplyVisualState()
      deferHideActions(row)
    end)
  end
end

--- Bind OnClick script to a row.
--- Left-click selects the conversation. Right-click opens the native player menu.
function RowScripts.bindClick(row, _item, options)
  if row.RegisterForClicks then
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  end

  if row.SetScript then
    row:SetScript("OnClick", function(self, button)
      if row.item == nil then
        return
      end

      if button == "RightButton" then
        if ContextMenu.Open(row.item, self or row) then
          return
        end
      end

      if options and options.onSelect then
        options.onSelect(row.item)
      end
    end)
  end
end

--- Bind drag-and-drop scripts to a row (pinned contacts only).
--- For pinned items: registers for drag and sets OnDragStart/OnDragStop.
--- For non-pinned items: clears drag registration and scripts.
function RowScripts.bindDrag(row, item, options)
  if item.pinned then
    if row.RegisterForDrag then
      row:RegisterForDrag("LeftButton")
    end
    if row.SetScript then
      row:SetScript("OnDragStart", function()
        if row.item and options and options.onDragStart then
          options.onDragStart(row, row.rowIndex)
        end
      end)
      row:SetScript("OnDragStop", function()
        if row.item and options and options.onDragStop then
          options.onDragStop(row, row.rowIndex)
        end
      end)
    end
  else
    row.dragButtons = nil
    if row.SetScript then
      row:SetScript("OnDragStart", nil)
      row:SetScript("OnDragStop", nil)
    end
  end
end

ns.ContactsListRowScripts = RowScripts
return RowScripts
