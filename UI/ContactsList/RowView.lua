local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local sizeValue = UIHelpers.sizeValue
local applyColorTexture = UIHelpers.applyColorTexture

local ActionButtons = ns.ContactsListActionButtons or require("WhisperMessenger.UI.ContactsList.ActionButtons")
local StatusDot = ns.ContactsListStatusDot or require("WhisperMessenger.UI.ContactsList.StatusDot")
local RowElements = ns.ContactsListRowElements or require("WhisperMessenger.UI.ContactsList.RowElements")
local RowTextAnchors = ns.ContactsListRowTextAnchors or require("WhisperMessenger.UI.ContactsList.RowTextAnchors")
local RowMarkers = ns.ContactsListRowMarkers or require("WhisperMessenger.UI.ContactsList.RowMarkers")
local RowScripts = ns.ContactsListRowScripts or require("WhisperMessenger.UI.ContactsList.RowScripts")
local RowHoverOverlay = ns.ContactsListRowHoverOverlay or require("WhisperMessenger.UI.ContactsList.RowHoverOverlay")
local GroupLabel = ns.ContactsListGroupLabel or require("WhisperMessenger.UI.ContactsList.GroupLabel")
local RowCompact = ns.ContactsListRowCompact or require("WhisperMessenger.UI.ContactsList.RowCompact")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")

local RowView = {}

-- Group rows use a slightly muted background (15% darker than the whisper
-- row base). Computed once at module load to avoid per-frame table creation.
local function mutedColor(base)
  if type(base) ~= "table" then
    return base
  end
  local MUTE = 0.85
  return { (base[1] or 0) * MUTE, (base[2] or 0) * MUTE, (base[3] or 0) * MUTE, base[4] or 1 }
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
  local ROW_HEIGHT = Theme.ContactRowHeight()
  row = row or factory.CreateFrame("Button", nil, parent)
  row.item = item
  -- Collapsed contacts rail: icon-only rows (see RowCompact).
  row._wmCompact = options ~= nil and options.compact == true
  -- 3px left inset on each row so contacts sit slightly tighter to the pane's
  -- left edge while keeping the right edge anchored to the parent.
  row:SetSize(parentWidth - Theme.LAYOUT.CONTACT_ROW_LEFT_INSET, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", Theme.LAYOUT.CONTACT_ROW_LEFT_INSET, -((index - 1) * ROW_HEIGHT))
  if row.EnableMouse then
    row:EnableMouse(true)
  end

  -- Background texture
  if row.bg == nil then
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
  end
  local isGroup = GroupLabel.IsGroupItem(item)
  local whisperBaseBg = item.pinned and Theme.COLORS.bg_contact_pinned or Theme.COLORS.bg_secondary
  local rowBaseBg = isGroup and mutedColor(whisperBaseBg) or whisperBaseBg
  applyColorTexture(row.bg, rowBaseBg)

  -- Left accent bar (shown when selected). The Native WoW HUD marks the
  -- selection with Blizzard highlight art instead.
  if not Hud.IsOn() then
    if row.accentBar == nil then
      row.accentBar = row:CreateTexture(nil, "BORDER")
      row.accentBar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
      row.accentBar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    end
    row.accentBar:SetWidth(Theme.LAYOUT.CONTACT_ACCENT_BAR_W)
    applyColorTexture(row.accentBar, Theme.COLORS.accent_bar)
    row.accentBar:Hide()
  end

  -- Event scripts (hover, click, drag).
  RowHoverOverlay.ensure(row)
  RowScripts.bindHover(row)
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
  RowMarkers.updateMuted(row, item)

  -- Refit name/faction now that timestamp width is known for this row.
  RowElements.updateNameLabel(row, item, parentWidth)
  RowElements.updateFactionIcon(row, item, ns)
  -- Faction icon hidden for group conversations (no Alliance/Horde context).
  -- Must happen AFTER updateFactionIcon, which shows the icon whenever a
  -- faction is resolved regardless of channel type.
  if isGroup and row.factionIcon and row.factionIcon.Hide then
    row.factionIcon:Hide()
  end

  -- For group rows, override the display name with the channel label.
  if isGroup and row.title then
    if row.title.SetText then
      row.title:SetText(GroupLabel.ForItem(item))
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
  RowElements.updatePreview(row, item, parentWidth, options and options.hideMessagePreview, options and options.selectedConversationKey)
  RowTextAnchors.anchorTextLines(row, ROW_HEIGHT)

  -- Location text (create once, update every bind). Group rows have no
  -- single member's zone to show, so it stays hidden for them.
  if row.location == nil then
    RowElements.createLocation(row, item, parentWidth)
  end
  RowElements.updateLocation(row, item, parentWidth)
  if isGroup and row.location and row.location.Hide then
    row.location:Hide()
  end

  -- Action buttons (create once)
  if row.removeButton == nil then
    row.removeButton = ActionButtons.createRemoveButton(factory, row, parentWidth, options)
  end
  if row.pinButton == nil then
    row.pinButton = ActionButtons.createPinButton(factory, row, item, parentWidth, options)
  end

  ActionButtons.paintPinIcon(row)
  ActionButtons.paintRemoveIcon(row)
  ActionButtons.layout(row)

  -- Actions show on hover only (and never under an unread badge).
  row.pinButton:Hide()
  row.removeButton:Hide()

  -- Unread badge (create once, update every bind)
  if row.unreadBadge == nil then
    RowElements.createUnreadBadge(factory, row)
  end
  RowElements.updateUnreadBadge(row, item)
  RowMarkers.updateBadge(row, item)
  RowCompact.apply(row, item, isGroup, row._wmCompact)

  if row.Show then
    row:Show()
  end

  return row
end

RowView.bindRow = bindRow

ns.ContactsListRowView = RowView
return RowView
