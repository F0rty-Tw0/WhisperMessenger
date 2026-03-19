local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local function loadModule(name, key)
  if ns[key] then return ns[key] end
  local ok, loaded = pcall(require, name)
  if ok then return loaded end
  error(key .. " module not available")
end
local Theme = loadModule("WhisperMessenger.UI.Theme", "Theme")

local ContactsList = {}
local PAGE_SIZE = 10

local function compareItems(left, right)
  if left.lastActivityAt ~= right.lastActivityAt then
    return left.lastActivityAt > right.lastActivityAt
  end

  return (left.displayName or "") < (right.displayName or "")
end

local function buildItem(conversationKey, conversation)
  return {
    conversationKey = conversationKey,
    displayName = conversation.displayName or conversation.contactDisplayName or conversationKey,
    lastPreview = conversation.lastPreview or "",
    unreadCount = conversation.unreadCount or 0,
    lastActivityAt = conversation.lastActivityAt or 0,
    channel = conversation.channel or "WOW",
    guid = conversation.guid,
    bnetAccountID = conversation.bnetAccountID,
    gameAccountName = conversation.gameAccountName,
    className = conversation.className,
    classTag = conversation.classTag,
    raceName = conversation.raceName,
    raceTag = conversation.raceTag,
    factionName = conversation.factionName,
  }
end

function ContactsList.BuildItems(conversations)
  local items = {}

  for conversationKey, conversation in pairs(conversations or {}) do
    table.insert(items, buildItem(conversationKey, conversation))
  end

  table.sort(items, compareItems)
  return items
end

function ContactsList.BuildItemsForProfile(savedState, localProfileId)
  local items = {}
  local profilePrefix = localProfileId .. "::"
  local bnetPrefix = "bnet::"

  for conversationKey, conversation in pairs(savedState.conversations or {}) do
    if string.find(conversationKey, profilePrefix, 1, true) == 1
        or string.find(conversationKey, bnetPrefix, 1, true) == 1 then
      table.insert(items, buildItem(conversationKey, conversation))
    end
  end

  table.sort(items, compareItems)
  return items
end

function ContactsList.SetSelected(rows, selectedConversationKey)
  for _, row in ipairs(rows or {}) do
    row.selected = row.item ~= nil and row.item.conversationKey == selectedConversationKey

    -- Update visual state for each row
    if row.bg then
      local c = row.selected and Theme.COLORS.bg_contact_selected or Theme.COLORS.bg_secondary
      row.bg:SetColorTexture(c[1], c[2], c[3], c[4])
    end

    if row.accentBar then
      if row.selected then
        row.accentBar:Show()
      else
        row.accentBar:Hide()
      end
    end
  end

  return selectedConversationKey
end

local function sizeValue(target, getterName, fieldName, fallback)
  if target and type(target[getterName]) == "function" then
    local value = target[getterName](target)
    if type(value) == "number" and value > 0 then
      return value
    end
  end

  if target and type(target[fieldName]) == "number" then
    return target[fieldName]
  end

  return fallback
end

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
  local bgColor = Theme.COLORS.bg_secondary
  row.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])

  -- Left accent bar (shown when selected)
  if row.accentBar == nil then
    row.accentBar = row:CreateTexture(nil, "BORDER")
    row.accentBar:SetSize(Theme.LAYOUT.CONTACT_ACCENT_BAR_W, ROW_HEIGHT)
    row.accentBar:SetPoint("LEFT", row, "LEFT", 0, 0)
    local ac = Theme.COLORS.accent_bar
    row.accentBar:SetColorTexture(ac[1], ac[2], ac[3], ac[4])
  end
  row.accentBar:Hide()

  -- Hover / selected scripts
  if row.SetScript then
    row:SetScript("OnEnter", function()
      if not row.selected then
        local hc = Theme.COLORS.bg_contact_hover
        row.bg:SetColorTexture(hc[1], hc[2], hc[3], hc[4])
      end
    end)

    row:SetScript("OnLeave", function()
      if row.selected then
        local sc = Theme.COLORS.bg_contact_selected
        row.bg:SetColorTexture(sc[1], sc[2], sc[3], sc[4])
      else
        local dc = Theme.COLORS.bg_secondary
        row.bg:SetColorTexture(dc[1], dc[2], dc[3], dc[4])
      end
    end)

    row:SetScript("OnClick", function()
      if row.item ~= nil and options.onSelect then
        options.onSelect(row.item)
      end
    end)
  end

  -- Class icon (40x40, left side)
  if row.classIcon == nil then
    row.classIcon = row:CreateTexture(nil, "ARTWORK")
    row.classIcon:SetSize(Theme.LAYOUT.CONTACT_ICON_SIZE, Theme.LAYOUT.CONTACT_ICON_SIZE)
    row.classIcon:SetPoint("LEFT", row, "LEFT", Theme.LAYOUT.CONTACT_PADDING, 0)
  end
  local iconPath = Theme.ClassIcon(item.classTag)
  if iconPath then
    row.classIcon:SetTexture(iconPath)
  else
    row.classIcon:SetTexture(Theme.TEXTURES.bnet_icon)
  end
  if row.classIcon.SetMask then
    row.classIcon:SetMask("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  end

  -- Status dot (10x10, bottom-right of class icon)
  if row.statusDot == nil then
    row.statusDot = row:CreateTexture(nil, "OVERLAY")
    row.statusDot:SetSize(Theme.LAYOUT.CONTACT_STATUS_SIZE, Theme.LAYOUT.CONTACT_STATUS_SIZE)
    row.statusDot:SetPoint("BOTTOMRIGHT", row.classIcon, "BOTTOMRIGHT", 2, -2)
    local oc = Theme.COLORS.online
    if row.statusDot.SetColorTexture then
      row.statusDot:SetColorTexture(oc[1], oc[2], oc[3], oc[4])
    end
    if row.statusDot.SetMask then
      row.statusDot:SetMask("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    end
  end

  -- Contact name (top line, class-colored)
  if row.title == nil then
    row.title = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_name)
    row.title:SetPoint("TOPLEFT", row.classIcon, "TOPRIGHT", 10, -4)
    row.title:SetWidth(parentWidth - Theme.LAYOUT.CONTACT_ICON_SIZE - Theme.LAYOUT.CONTACT_PADDING - 160)
  end
  row.title:SetText(item.displayName)
  if RAID_CLASS_COLORS and item.classTag and RAID_CLASS_COLORS[item.classTag] then
    local cc = RAID_CLASS_COLORS[item.classTag]
    row.title:SetTextColor(cc.r, cc.g, cc.b, 1)
  else
    local tc = Theme.COLORS.text_primary
    row.title:SetTextColor(tc[1], tc[2], tc[3], tc[4])
  end

  -- Faction icon (14x14, after name)
  if row.factionIcon == nil then
    row.factionIcon = row:CreateTexture(nil, "ARTWORK")
    row.factionIcon:SetSize(Theme.LAYOUT.CONTACT_FACTION_SIZE, Theme.LAYOUT.CONTACT_FACTION_SIZE)
    row.factionIcon:SetPoint("LEFT", row.title, "RIGHT", 4, 0)
  end
  local factionPath = Theme.FactionIcon(item.factionName)
  if factionPath then
    row.factionIcon:SetTexture(factionPath)
    row.factionIcon:Show()
  else
    row.factionIcon:Hide()
  end

  -- Timestamp (top-right)
  if row.timeLabel == nil then
    row.timeLabel = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_time)
    row.timeLabel:SetPoint("TOPRIGHT", row, "TOPRIGHT", -Theme.LAYOUT.CONTACT_PADDING, -4)
    local ts = Theme.COLORS.text_secondary
    row.timeLabel:SetTextColor(ts[1], ts[2], ts[3], ts[4])
  end
  if ns.TimeFormat and ns.TimeFormat.ContactPreview then
    row.timeLabel:SetText(ns.TimeFormat.ContactPreview(item.lastActivityAt))
  else
    row.timeLabel:SetText("")
  end

  -- Preview text (bottom line)
  if row.preview == nil then
    row.preview = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_preview)
    row.preview:SetPoint("TOPLEFT", row.classIcon, "TOPRIGHT", 10, -28)
    local ps = Theme.COLORS.text_secondary
    row.preview:SetTextColor(ps[1], ps[2], ps[3], ps[4])
    row.preview:SetWidth(parentWidth - Theme.LAYOUT.CONTACT_ICON_SIZE - Theme.LAYOUT.CONTACT_PADDING - 40)
  end
  row.preview:SetText(item.lastPreview or "")

  -- Unread badge (bottom-right, circular)
  if row.unreadBadge == nil then
    row.unreadBadge = factory.CreateFrame("Frame", nil, row)
    row.unreadBadge:SetSize(20, 20)
    row.unreadBadge:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -Theme.LAYOUT.CONTACT_PADDING, 12)

    row.unreadBadge.bg = row.unreadBadge:CreateTexture(nil, "BACKGROUND")
    row.unreadBadge.bg:SetAllPoints()
    local ub = Theme.COLORS.unread_badge
    row.unreadBadge.bg:SetColorTexture(ub[1], ub[2], ub[3], ub[4])
    if row.unreadBadge.bg.SetMask then
      row.unreadBadge.bg:SetMask("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    end

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
      row.bg:SetColorTexture(c[1], c[2], c[3], c[4])
    end
    if row.accentBar then
      row.accentBar:Hide()
    end
    if row.title then
      row.title:SetText("")
    end
    if row.preview then
      row.preview:SetText("")
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
