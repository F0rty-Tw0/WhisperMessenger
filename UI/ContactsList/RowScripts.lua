local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture

local ContextMenu = ns.ContactsListContextMenu or require("WhisperMessenger.UI.ContactsList.ContextMenu")

local RowScripts = {}

local function showActions(row)
  local hasUnread = row.item and (row.item.unreadCount or 0) > 0
  if hasUnread then
    return
  end
  if row.pinButton then
    row.pinButton:Show()
  end
  if row.removeButton then
    row.removeButton:Show()
  end
end

local function hideActions(row)
  if row.pinButton and not (row.item and row.item.pinned) then
    row.pinButton:Hide()
  end
  if row.removeButton then
    row.removeButton:Hide()
  end
end

--- Bind OnEnter / OnLeave hover scripts to a row.
--- options may include: rowBaseBg (color table for base background)
function RowScripts.bindHover(row, options)
  local rowBaseBg = options and options.rowBaseBg
    or (row.item and row.item.pinned and Theme.COLORS.bg_contact_pinned or Theme.COLORS.bg_secondary)

  if row.SetScript then
    row:SetScript("OnEnter", function()
      if not row.selected then
        applyColorTexture(row.bg, Theme.COLORS.bg_contact_hover)
      end
      showActions(row)
    end)

    row:SetScript("OnLeave", function()
      if row.IsMouseOver and row:IsMouseOver() then
        return
      end
      if row.selected then
        applyColorTexture(row.bg, Theme.COLORS.bg_contact_selected)
      else
        applyColorTexture(row.bg, rowBaseBg)
      end
      hideActions(row)
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
