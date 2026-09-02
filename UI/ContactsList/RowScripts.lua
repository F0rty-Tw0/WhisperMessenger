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

local function stopHoverWatchdog(row)
  if not row._wmHoverWatchdogInstalled then
    return
  end

  local previous = row._wmHoverWatchdogPreviousOnUpdate
  row._wmHoverWatchdogInstalled = false
  row._wmHoverWatchdogPreviousOnUpdate = nil
  row._wmHoverWatchdogElapsed = 0
  if row.SetScript then
    row:SetScript("OnUpdate", previous)
  end
end

--- Schedule hideActions for the next frame so button OnEnter/Row OnEnter
--- can fire first, preventing re-entrant hover events from frame hiding.
local function deferHideActions(row)
  local CTimer = _G.C_Timer
  if CTimer and CTimer.After then
    CTimer.After(0, function()
      local AB = getActionButtons()
      local pointerInside = (row._wmIsPointerInside and row._wmIsPointerInside()) or isPointerInsideRow(row)
      if not pointerInside and effectiveActionHoverCount(row) == 0 then
        row._wmRowHover = false
        row._wmApplyVisualState()
        if AB then
          AB.hideActions(row)
        end
        stopHoverWatchdog(row)
      end
    end)
  else
    local AB = getActionButtons()
    local pointerInside = (row._wmIsPointerInside and row._wmIsPointerInside()) or isPointerInsideRow(row)
    if not pointerInside and effectiveActionHoverCount(row) == 0 then
      row._wmRowHover = false
      row._wmApplyVisualState()
      if AB then
        AB.hideActions(row)
      end
      stopHoverWatchdog(row)
    end
  end
end

local function applyRowVisualState(row)
  local hovered = row._wmRowHover == true
    or (row._wmActionHoverCount or 0) > 0
    or ((row._wmIsPointerInside and row._wmIsPointerInside()) or isPointerInsideRow(row))
  if row.selected then
    applyColorTexture(row.bg, Theme.COLORS.bg_contact_selected)
  elseif hovered then
    applyColorTexture(row.bg, Theme.COLORS.bg_contact_hover)
  elseif row.item and row.item.pinned then
    applyColorTexture(row.bg, Theme.COLORS.bg_contact_pinned)
  else
    applyColorTexture(row.bg, { 0, 0, 0, 0 })
  end
  if row.selectedRightBorder then
    applyColorTexture(row.selectedRightBorder, Theme.COLORS.contact_selected_border_right or Theme.COLORS.accent_bar)
    if row.selected then
      row.selectedRightBorder:Show()
    else
      row.selectedRightBorder:Hide()
    end
  end

  -- Stage 2C: bundled Blizzard chrome paints a hover/selected overlay on
  -- top of row.bg. Only visible when a texture is set (blizzard skin sets
  -- it via RowView; modern skin leaves it nil so this branch no-ops).
  if row.skinHighlight then
    local hasTexture = row.skinHighlight.GetTexture and row.skinHighlight:GetTexture()
    if hasTexture then
      if row.selected then
        if row.skinHighlight.SetAlpha then
          row.skinHighlight:SetAlpha(0.6)
        end
        row.skinHighlight:Show()
      elseif hovered then
        if row.skinHighlight.SetAlpha then
          row.skinHighlight:SetAlpha(0.4)
        end
        row.skinHighlight:Show()
      else
        row.skinHighlight:Hide()
      end
    else
      row.skinHighlight:Hide()
    end
  end
end

local function installHoverWatchdog(row)
  if row._wmHoverWatchdogInstalled or not row.SetScript then
    return
  end
  row._wmHoverWatchdogInstalled = true
  row._wmHoverWatchdogPreviousOnUpdate = row.GetScript and row:GetScript("OnUpdate") or nil
  row._wmHoverWatchdogElapsed = 0

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
      stopHoverWatchdog(self)
      return
    end

    local actionHoverCount = effectiveActionHoverCount(self)
    local hadHoverState = self._wmRowHover or actionHoverCount > 0
    if not hadHoverState then
      stopHoverWatchdog(self)
      return
    end

    local pointerInside = (self._wmIsPointerInside and self._wmIsPointerInside()) or isPointerInsideRow(self)
    if pointerInside then
      return
    end

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
    stopHoverWatchdog(self)
  end)
end

--- Bind OnEnter / OnLeave hover scripts to a row.
--- options may include: rowBaseBg (color table for base background)
--- Rows are re-bound on every refresh, so the closures are created once and
--- read their state (row.item, row.selected) live at call time.
function RowScripts.bindHover(row, options)
  stopHoverWatchdog(row)
  row._wmRowBaseBg = (options and options.rowBaseBg) or (row.item and row.item.pinned and Theme.COLORS.bg_contact_pinned or Theme.COLORS.bg_secondary)
  row._wmRowHover = false
  row._wmActionHoverCount = 0

  if not row._wmHoverBound then
    row._wmHoverBound = true
    row._wmIsPointerInside = function()
      return isPointerInsideRow(row)
    end
    row._wmApplyVisualState = function()
      applyRowVisualState(row)
    end

    if row.SetScript then
      row:SetScript("OnEnter", function()
        if row.selected then
          stopHoverWatchdog(row)
        else
          installHoverWatchdog(row)
        end
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

  row._wmApplyVisualState()
end

--- Bind OnClick script to a row.
--- Left-click selects the conversation. Right-click opens the native player menu.
--- The handler is created once per row and reads row._wmRowOptions, so a later
--- refresh with fresh callbacks takes effect without rebinding.
function RowScripts.bindClick(row, _item, options)
  row._wmRowOptions = options
  if row.RegisterForClicks then
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  end

  if not row._wmClickBound and row.SetScript then
    row._wmClickBound = true
    row:SetScript("OnClick", function(self, button)
      if row.item == nil then
        return
      end

      local rowOptions = row._wmRowOptions
      if button == "RightButton" then
        if ContextMenu.Open(row.item, self or row, rowOptions and rowOptions.onMarkUnread) then
          return
        end
      end

      if rowOptions and rowOptions.onSelect then
        rowOptions.onSelect(row.item)
      end
    end)
  end
end

--- Bind drag-and-drop scripts to a row (pinned contacts only).
--- The handlers are attached once and stay attached; they no-op unless the item
--- the row currently holds is pinned. Drag registration is still toggled on
--- every bind: it is sticky on pooled row Buttons, and a registered-but-inert
--- drag swallows clicks.
function RowScripts.bindDrag(row, item, options)
  row._wmRowOptions = options

  if not row._wmDragBound and row.SetScript then
    row._wmDragBound = true
    row:SetScript("OnDragStart", function()
      local rowOptions = row._wmRowOptions
      if row.item and row.item.pinned and rowOptions and rowOptions.onDragStart then
        rowOptions.onDragStart(row, row.rowIndex)
      end
    end)
    row:SetScript("OnDragStop", function()
      local rowOptions = row._wmRowOptions
      if row.item and row.item.pinned and rowOptions and rowOptions.onDragStop then
        rowOptions.onDragStop(row, row.rowIndex)
      end
    end)
  end

  if row.RegisterForDrag then
    if item.pinned then
      row:RegisterForDrag("LeftButton")
    else
      -- No arguments = unregister.
      row:RegisterForDrag()
    end
  end
end

ns.ContactsListRowScripts = RowScripts
return RowScripts
