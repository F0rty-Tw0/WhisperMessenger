local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Skins = ns.Skins or require("WhisperMessenger.UI.Theme.Skins")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local sizeValue = UIHelpers.sizeValue
local applyColorTexture = UIHelpers.applyColorTexture
local applyVertexColor = UIHelpers.applyVertexColor

local ActionButtons = ns.ContactsListActionButtons or require("WhisperMessenger.UI.ContactsList.ActionButtons")
local StatusDot = ns.ContactsListStatusDot or require("WhisperMessenger.UI.ContactsList.StatusDot")
local RowElements = ns.ContactsListRowElements or require("WhisperMessenger.UI.ContactsList.RowElements")
local RowScripts = ns.ContactsListRowScripts or require("WhisperMessenger.UI.ContactsList.RowScripts")
local GroupLabel = ns.ContactsListGroupLabel or require("WhisperMessenger.UI.ContactsList.GroupLabel")
local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")

local RowView = {}
local ROW_HEIGHT = Theme.LAYOUT.CONTACT_ROW_HEIGHT
local ACTIONS_RIGHT_INSET = 4

-- Group rows use a slightly muted background (15% darker than the whisper
-- row base). Computed once at module load to avoid per-frame table creation.
local function mutedColor(base)
  if type(base) ~= "table" then
    return base
  end
  local MUTE = 0.85
  return { (base[1] or 0) * MUTE, (base[2] or 0) * MUTE, (base[3] or 0) * MUTE, base[4] or 1 }
end

-- Only explicitly-known Stage-4 group-ingest channel values get group-row
-- styling. Legacy values ("WOW", "BN", nil) render as normal whisper rows.
local KNOWN_GROUP_CHANNELS = {
  [ChannelType.BN_CONVERSATION] = true,
  [ChannelType.PARTY] = true,
  [ChannelType.RAID] = true,
  [ChannelType.INSTANCE_CHAT] = true,
  [ChannelType.GUILD] = true,
  [ChannelType.OFFICER] = true,
  [ChannelType.CHANNEL] = true,
  [ChannelType.COMMUNITY] = true,
}

-- isGroupItem returns true when the item represents a known group conversation.
local function isGroupItem(item)
  return item ~= nil and KNOWN_GROUP_CHANNELS[item.channel] == true
end

-- Resolve and cache the current player's class tag (e.g. "MAGE"). Group
-- rows tint their title by the player's class color rather than by the
-- last message sender's class, so the row reads as *yours*.
local cachedPlayerClassTag = nil
local function playerClassTag()
  if cachedPlayerClassTag ~= nil then
    return cachedPlayerClassTag
  end
  local unitClass = _G.UnitClass
  if type(unitClass) ~= "function" then
    return nil
  end
  local ok, _, tag = pcall(unitClass, "player")
  if ok and type(tag) == "string" and tag ~= "" then
    cachedPlayerClassTag = tag
    return cachedPlayerClassTag
  end
  return nil
end

local function bindRow(factory, parent, row, index, item, options)
  local parentWidth = sizeValue(parent, "GetWidth", "width", 260)
  row = row or factory.CreateFrame("Button", nil, parent)
  row.item = item
  -- 3px left inset on each row so contacts sit slightly tighter to the pane's
  -- left edge while keeping the right edge anchored to the parent.
  row:SetSize(parentWidth - 2, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, -((index - 1) * ROW_HEIGHT))
  if row.EnableMouse then
    row:EnableMouse(true)
  end

  -- Background texture
  if row.bg == nil then
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
  end
  local isGroup = isGroupItem(item)
  local whisperBaseBg = item.pinned and Theme.COLORS.bg_contact_pinned or Theme.COLORS.bg_secondary
  local rowBaseBg = isGroup and mutedColor(whisperBaseBg) or whisperBaseBg
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

  -- Stage 2C: bundled Blizzard chrome paints a hover/selected highlight
  -- overlay on top of row.bg. The overlay is created unconditionally so the
  -- shape stays stable across skin switches; only its texture path is
  -- skin-dependent. RowScripts.applyRowVisualState shows/hides it based on
  -- hover/selected state when a texture is set; modern skin leaves the
  -- texture nil so it never paints.
  if row.skinHighlight == nil then
    row.skinHighlight = row:CreateTexture(nil, "ARTWORK")
    row.skinHighlight:SetAllPoints()
  end
  local rowSkinSpec = Skins.Get(Skins.GetActive())
  if rowSkinSpec and rowSkinSpec.contact_row_highlight_texture and row.skinHighlight.SetTexture then
    row.skinHighlight:SetTexture(rowSkinSpec.contact_row_highlight_texture)
    if row.skinHighlight.SetBlendMode then
      row.skinHighlight:SetBlendMode("ADD")
    end
  elseif row.skinHighlight.SetTexture then
    row.skinHighlight:SetTexture(nil)
  end
  row.skinHighlight:Hide()

  -- Event scripts (hover, click, drag)
  RowScripts.bindHover(row, { rowBaseBg = rowBaseBg })
  RowScripts.bindClick(row, item, options)
  row.rowIndex = index
  RowScripts.bindDrag(row, item, options)

  -- Class icon (create once, update texture every bind).
  -- Group rows override with a channel-type icon (guild, party, raid, etc.)
  -- since there's no single "class" for a group thread.
  if row.classIconFrame == nil then
    RowElements.createClassIcon(factory, row, item)
  end
  if row.classIcon and row.classIcon.SetTexture then
    local iconPath
    if isGroup then
      iconPath = Theme.ChannelIcon and Theme.ChannelIcon(item.channel) or nil
    else
      iconPath = Theme.ClassIcon(item.classTag)
    end
    row.classIcon:SetTexture(iconPath or Theme.TEXTURES.bnet_icon)
  end

  -- Status dot (create once, update color every bind)
  -- Hidden for group conversations (no per-member presence).
  if row.statusDot == nil then
    row.statusDot = StatusDot.create(factory, row, row.classIconFrame, item.availability).frame
  else
    StatusDot.update(row.statusDot, item.availability)
  end
  if row.statusDot and row.statusDot.SetShown then
    row.statusDot:SetShown(not isGroup)
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
  -- Faction icon hidden for group conversations (no Alliance/Horde context).
  -- Must happen AFTER updateFactionIcon, which shows the icon whenever a
  -- faction is resolved regardless of channel type.
  if isGroup and row.factionIcon and row.factionIcon.Hide then
    row.factionIcon:Hide()
  end

  -- For group rows, override the display name with the channel label so the
  -- row shows "Party", "Instance (BG)", etc. rather than the internal key.
  if isGroup and row.title then
    local convTitle = item.title or nil
    local groupName = GroupLabel.LabelForChannelAndTitle(item.channel, convTitle)
    if groupName == "" then
      groupName = item.displayName or ""
    end
    -- Group chats carried over from another character get an owner prefix
    -- ("Jaina — Guild") so the player can tell which alt's history this is.
    local ownerName = GroupLabel.OwnerShortName and GroupLabel.OwnerShortName(item.ownerProfileId) or nil
    if ownerName then
      groupName = ownerName .. " — " .. groupName
    end
    if row.title.SetText then
      row.title:SetText(groupName)
    end
    -- Tint the group row's title by the OWNER character's class color.
    -- `ownerClassTag` is populated from the saved player→class map when
    -- the owner has logged in at least once since the feature landed.
    -- For current-character rows (no foreign owner) we fall back to the
    -- live player class so the label colors correctly before the map
    -- has been stamped. For foreign-owner rows where we haven't seen
    -- the character yet, pass nil so applyClassColor uses the neutral
    -- text color rather than mis-tinting with the current player's
    -- class. updateNameLabel / updateFactionIcon above painted with
    -- item.classTag (= last sender's class), so re-apply here.
    local titleClassTag = item.ownerClassTag
    if titleClassTag == nil and not item.ownerProfileId then
      titleClassTag = playerClassTag()
    end
    UIHelpers.applyClassColor(row.title, titleClassTag, Theme.COLORS.text_primary)
  end

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
    row.unreadBadge:SetSize(16, 16)
    row.unreadBadge:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -Theme.LAYOUT.CONTACT_PADDING + 4, 12)
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
