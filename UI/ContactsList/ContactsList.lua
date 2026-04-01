local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local sizeValue = UIHelpers.sizeValue
local applyColorTexture = UIHelpers.applyColorTexture
local setTextColor = UIHelpers.setTextColor

local DataBuilder = ns.ContactsListDataBuilder or require("WhisperMessenger.UI.ContactsList.DataBuilder")
local RowView = ns.ContactsListRowView or require("WhisperMessenger.UI.ContactsList.RowView")
local bindRow = RowView.bindRow
local ROW_HEIGHT = RowView.ROW_HEIGHT

local ContactsList = {}

-- Re-export data builder functions
ContactsList.BuildItems = DataBuilder.BuildItems
ContactsList.BuildItemsForProfile = DataBuilder.BuildItemsForProfile

function ContactsList.SetSelected(rows, selectedConversationKey)
  for _, row in ipairs(rows or {}) do
    row.selected = row.item ~= nil and row.item.conversationKey == selectedConversationKey
    local baseColor = (row.item and row.item.pinned and Theme.COLORS.bg_contact_pinned) or Theme.COLORS.bg_secondary
    row._wmRowBaseBg = baseColor

    if row._wmApplyVisualState then
      row._wmApplyVisualState()
    elseif row.bg then
      local c = row.selected and Theme.COLORS.bg_contact_selected or baseColor
      applyColorTexture(row.bg, c)
    end

    if row.accentBar then
      applyColorTexture(row.accentBar, Theme.COLORS.accent_bar)
      if row.selected then
        row.accentBar:Show()
      else
        row.accentBar:Hide()
      end
    end
    if row.selectedRightBorder then
      applyColorTexture(row.selectedRightBorder, Theme.COLORS.contact_selected_border_right or Theme.COLORS.accent_bar)
      if row.selected then
        row.selectedRightBorder:Show()
      else
        row.selectedRightBorder:Hide()
      end
    end

    if row.preview then
      local previewColor = row.selected and Theme.COLORS.text_primary or Theme.COLORS.text_secondary
      setTextColor(row.preview, previewColor)
    end
  end

  return selectedConversationKey
end

function ContactsList.Refresh(factory, parent, rows, items, options)
  rows = rows or {}
  items = items or {}
  options = options or {}

  local visibleCount = options.visibleCount or #items
  if visibleCount > #items then
    visibleCount = #items
  end

  for index = 1, visibleCount do
    rows[index] = bindRow(factory, parent, rows[index], index, items[index], options)
  end

  for index = visibleCount + 1, #rows do
    local row = rows[index]
    row.item = nil
    row.selected = false

    if row.bg then
      local c = Theme.COLORS.bg_secondary
      applyColorTexture(row.bg, c)
    end
    if row.accentBar then
      row.accentBar:Hide()
    end
    if row.selectedRightBorder then
      row.selectedRightBorder:Hide()
    end
    if row.title then
      row.title:SetText("")
    end
    if row.preview then
      row.preview:SetText("")
      setTextColor(row.preview, Theme.COLORS.text_secondary)
    end
    if row.timeLabel then
      row.timeLabel:SetText("")
    end
    if row.unreadBadge then
      row.unreadBadge:Hide()
    end
    if row.Hide then
      row:Hide()
    end
  end

  local parentWidth = sizeValue(parent, "GetWidth", "width", 260)
  local viewport = parent and parent.parent or nil
  local viewportHeight = sizeValue(viewport, "GetHeight", "height", visibleCount * ROW_HEIGHT)
  local contentHeight = math.max(viewportHeight, visibleCount * ROW_HEIGHT)

  if parent and parent.SetSize then
    parent:SetSize(parentWidth, contentHeight)
  end

  if viewport and type(viewport.UpdateScrollChildRect) == "function" then
    viewport:UpdateScrollChildRect()
  end

  parent.rows = rows
  parent.visibleCount = visibleCount
  parent.totalCount = #items
  ContactsList.SetSelected(rows, options.selectedConversationKey)
  return rows
end

function ContactsList.HasMore(parent)
  if parent == nil then
    return false
  end
  return (parent.visibleCount or 0) < (parent.totalCount or 0)
end

function ContactsList.Render(factory, parent, items, options)
  return ContactsList.Refresh(factory, parent, {}, items, options)
end

ns.ContactsList = ContactsList
return ContactsList
