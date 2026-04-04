local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local sizeValue = UIHelpers.sizeValue
local applyColorTexture = UIHelpers.applyColorTexture
local applyVertexColor = UIHelpers.applyVertexColor

local ActionButtons = ns.ContactsListActionButtons or require("WhisperMessenger.UI.ContactsList.ActionButtons")
local StatusDot = ns.ContactsListStatusDot or require("WhisperMessenger.UI.ContactsList.StatusDot")
local RowElements = ns.ContactsListRowElements or require("WhisperMessenger.UI.ContactsList.RowElements")
local RowScripts = ns.ContactsListRowScripts or require("WhisperMessenger.UI.ContactsList.RowScripts")

local RowView = {}
local ROW_HEIGHT = Theme.LAYOUT.CONTACT_ROW_HEIGHT
local ACTIONS_RIGHT_INSET = 4

local function bindRow(factory, parent, row, index, item, options)
  local parentWidth = sizeValue(parent, "GetWidth", "width", 260)
  row = row or factory.CreateFrame("Button", nil, parent)
  row.item = item
  row:SetSize(parentWidth, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
  if row.EnableMouse then
    row:EnableMouse(true)
  end

  -- Background texture
  if row.bg == nil then
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
  end
  local rowBaseBg = item.pinned and Theme.COLORS.bg_contact_pinned or Theme.COLORS.bg_secondary
  applyColorTexture(row.bg, rowBaseBg)

  -- Left accent bar (shown when selected)
  if row.accentBar == nil then
    row.accentBar = row:CreateTexture(nil, "BORDER")
    row.accentBar:SetSize(Theme.LAYOUT.CONTACT_ACCENT_BAR_W, ROW_HEIGHT)
    row.accentBar:SetPoint("LEFT", row, "LEFT", 0, 0)
    applyColorTexture(row.accentBar, Theme.COLORS.accent_bar)
  end
  applyColorTexture(row.accentBar, Theme.COLORS.accent_bar)
  row.accentBar:Hide()

  -- Right border for selected row
  if row.selectedRightBorder == nil then
    row.selectedRightBorder = row:CreateTexture(nil, "BORDER")
    row.selectedRightBorder:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.selectedRightBorder:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.selectedRightBorder:SetWidth(2)
  end
  applyColorTexture(row.selectedRightBorder, Theme.COLORS.contact_selected_border_right or Theme.COLORS.accent_bar)
  row.selectedRightBorder:Hide()
  -- Event scripts (hover, click, drag)
  RowScripts.bindHover(row, { rowBaseBg = rowBaseBg })
  RowScripts.bindClick(row, item, options)
  row.rowIndex = index
  RowScripts.bindDrag(row, item, options)

  -- Class icon (create once, update texture every bind)
  if row.classIconFrame == nil then
    RowElements.createClassIcon(factory, row, item)
  else
    local iconPath = Theme.ClassIcon(item.classTag)
    row.classIcon:SetTexture(iconPath or Theme.TEXTURES.bnet_icon)
  end

  -- Status dot (create once, update color every bind)
  if row.statusDot == nil then
    row.statusDot = StatusDot.create(factory, row, row.classIconFrame, item.availability).frame
  else
    StatusDot.update(row.statusDot, item.availability)
  end

  -- Contact name + faction icon (create once, update every bind)
  if row.title == nil then
    RowElements.createNameLabel(row, item, parentWidth)
  end
  if row.factionIcon == nil then
    RowElements.createFactionIcon(factory, row, item, ns)
  end

  -- Timestamp (create once, update text every bind)
  if row.timeLabel == nil then
    RowElements.createTimestamp(row, item, ns)
  else
    RowElements.updateTimestamp(row, item, ns)
  end

  -- Refit name/faction now that timestamp width is known for this row.
  RowElements.updateNameLabel(row, item, parentWidth)
  RowElements.updateFactionIcon(row, item, ns)

  -- Preview text (create once, update text every bind)
  if row.preview == nil then
    RowElements.createPreview(row, item, parentWidth)
  end
  RowElements.updatePreview(row, item, parentWidth, options and options.hideMessagePreview)

  -- Action buttons (create once)
  if row.removeButton == nil then
    row.removeButton = ActionButtons.createRemoveButton(factory, row, parentWidth, options)
  end
  if row.pinButton == nil then
    row.pinButton = ActionButtons.createPinButton(factory, row, item, parentWidth, options)
  end

  -- Update action icon appearance and position just below the timestamp.
  local pinTex = item.pinned and Theme.TEXTURES.pin_down_icon or Theme.TEXTURES.pin_up_icon
  row.pinButton.icon:SetTexture(pinTex)
  local pinColor = item.pinned and Theme.COLORS.action_icon_pinned or Theme.COLORS.action_icon
  applyVertexColor(row.pinButton.icon, pinColor)
  local ACTION_SPACING = Theme.LAYOUT.CONTACT_ACTION_SPACING

  row.removeButton:ClearAllPoints()
  if row.timeLabel then
    row.removeButton:SetPoint("TOPRIGHT", row.timeLabel, "BOTTOMRIGHT", ACTIONS_RIGHT_INSET, -ACTION_SPACING)
  else
    row.removeButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", -Theme.LAYOUT.CONTACT_PADDING, -ACTION_SPACING)
  end

  row.pinButton:ClearAllPoints()
  local pinYOffset = item.pinned and (-ACTION_SPACING + 4) or (-ACTION_SPACING + 10)
  row.pinButton:SetPoint("TOP", row.removeButton, "BOTTOM", 0, pinYOffset)

  -- Show/hide action buttons: hide when unread badge is visible
  local hasUnread = (item.unreadCount or 0) > 0
  if not hasUnread and item.pinned then
    row.pinButton:Show()
  else
    row.pinButton:Hide()
  end
  row.removeButton:Hide()

  -- Unread badge (create once, update every bind)
  if row.unreadBadge == nil then
    row.unreadBadge = factory.CreateFrame("Frame", nil, row)
    row.unreadBadge:SetSize(20, 20)
    row.unreadBadge:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -Theme.LAYOUT.CONTACT_PADDING, 12)
    row.unreadBadge.bg = row.unreadBadge:CreateTexture(nil, "BACKGROUND")
    row.unreadBadge.bg:SetAllPoints()
    row.unreadBadge.bg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    UIHelpers.applyVertexColor(row.unreadBadge.bg, Theme.COLORS.unread_badge)
    row.unreadBadge.label = row.unreadBadge:CreateFontString(nil, "OVERLAY", Theme.FONTS.unread_badge)
    row.unreadBadge.label:SetAllPoints()
    row.unreadBadge.label:SetJustifyH("CENTER")
    row.unreadBadge.label:SetJustifyV("MIDDLE")
  end

  local count = item.unreadCount or 0
  if count > 0 then
    local badgeText = count > 99 and "99+" or tostring(count)
    row.unreadBadge.label:SetText(badgeText)
    row.unreadBadge:Show()
  else
    row.unreadBadge:Hide()
  end

  if row.Show then
    row:Show()
  end

  return row
end

RowView.bindRow = bindRow
RowView.ROW_HEIGHT = ROW_HEIGHT

ns.ContactsListRowView = RowView
return RowView
