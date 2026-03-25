local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local sizeValue = UIHelpers.sizeValue
local applyClassColor = UIHelpers.applyClassColor
local applyColorTexture = UIHelpers.applyColorTexture
local applyVertexColor = UIHelpers.applyVertexColor

local ActionButtons = ns.ContactsListActionButtons or require("WhisperMessenger.UI.ContactsList.ActionButtons")
local StatusDot = ns.ContactsListStatusDot or require("WhisperMessenger.UI.ContactsList.StatusDot")
local RowElements = ns.ContactsListRowElements or require("WhisperMessenger.UI.ContactsList.RowElements")
local RowScripts = ns.ContactsListRowScripts or require("WhisperMessenger.UI.ContactsList.RowScripts")

local RowView = {}
local ROW_HEIGHT = Theme.LAYOUT.CONTACT_ROW_HEIGHT

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
  row.accentBar:Hide()

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
    local dot = StatusDot.create(factory, row, row.classIconFrame, item.availability)
    row.statusDot = dot.frame
    row.statusDot.bg = dot.texture
  else
    local colorKey
    if item.availability then
      colorKey = item.availability.canWhisper and "online" or "offline"
      if item.availability.status == "WrongFaction" then
        colorKey = "dnd"
      elseif item.availability.status == "Away" then
        colorKey = "away"
      elseif item.availability.status == "Busy" then
        colorKey = "dnd"
      elseif item.availability.status == "BNetOnline" then
        colorKey = "away"
      elseif item.availability.status == "Unavailable" then
        colorKey = "offline"
      end
    else
      colorKey = "offline"
    end
    local sc = Theme.COLORS[colorKey]
    if sc then
      row.statusDot.bg:SetVertexColor(sc[1], sc[2], sc[3], sc[4] or 1)
    end
    row.statusDot:Show()
  end

  -- Contact name (create once, update text every bind)
  if row.title == nil then
    RowElements.createNameLabel(row, item, parentWidth)
  else
    row.title:SetText(item.displayName)
    applyClassColor(row.title, item.classTag, Theme.COLORS.text_primary)
  end

  -- Faction icon (create once, update every bind)
  if row.factionIcon == nil then
    RowElements.createFactionIcon(factory, row, item, ns)
  else
    local titleTextWidth = row.title.GetStringWidth and row.title:GetStringWidth() or 0
    local titleMaxWidth = row.title.GetWidth and row.title:GetWidth() or 0
    local textW = math.min(titleTextWidth, titleMaxWidth)
    row.factionIcon:ClearAllPoints()
    row.factionIcon:SetPoint("LEFT", row.title, "LEFT", textW + 4, 0)
    local inferredFaction = item.raceTag
        and (ns.Identity and ns.Identity.InferFaction and ns.Identity.InferFaction(item.raceTag))
      or nil
    local factionForIcon = inferredFaction or item.factionName
    local reliableFaction = factionForIcon and Theme.FactionIcon(factionForIcon) or nil
    if reliableFaction then
      row.factionIcon:SetTexture(reliableFaction)
      row.factionIcon:Show()
    else
      row.factionIcon:Hide()
    end
  end

  -- Timestamp (create once, update text every bind)
  if row.timeLabel == nil then
    RowElements.createTimestamp(row, item, ns)
  else
    if ns.TimeFormat and ns.TimeFormat.ContactPreview then
      row.timeLabel:SetText(ns.TimeFormat.ContactPreview(item.lastActivityAt))
    else
      row.timeLabel:SetText("")
    end
  end

  -- Preview text (create once, update text every bind)
  local previewText = options.hideMessagePreview and "" or (item.lastPreview or "")
  if row.preview == nil then
    RowElements.createPreview(row, item, parentWidth)
    row.preview:SetText(previewText)
  else
    row.preview:SetText(previewText)
  end

  -- Action buttons (create once)
  if row.removeButton == nil then
    row.removeButton = ActionButtons.createRemoveButton(factory, row, parentWidth, options)
  end
  if row.pinButton == nil then
    row.pinButton = ActionButtons.createPinButton(factory, row, item, parentWidth, options)
  end

  -- Update pin icon appearance and position
  local pinTex = item.pinned and Theme.TEXTURES.pin_down_icon or Theme.TEXTURES.pin_up_icon
  row.pinButton.icon:SetTexture(pinTex)
  local pinColor = item.pinned and Theme.COLORS.action_icon_pinned or Theme.COLORS.action_icon
  applyVertexColor(row.pinButton.icon, pinColor)
  row.pinButton:ClearAllPoints()
  local ACTION_SPACING = Theme.LAYOUT.CONTACT_ACTION_SPACING
  local pinYOffset = item.pinned and 0 or 6
  row.pinButton:SetPoint("TOP", row.removeButton, "BOTTOM", 0, -ACTION_SPACING + pinYOffset)

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
