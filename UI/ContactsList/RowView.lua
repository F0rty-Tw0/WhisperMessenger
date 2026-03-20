local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

local Loader = ns.Loader or require("WhisperMessenger.Core.Loader")
local loadModule = Loader.LoadModule
local Theme = loadModule("WhisperMessenger.UI.Theme", "Theme")
local UIHelpers = loadModule("WhisperMessenger.UI.Helpers", "UIHelpers")
local sizeValue = UIHelpers.sizeValue

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

  -- Status dot (10x10, bottom-right of class icon) — hidden until online tracking is implemented
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
  local avail = item.availability
  if avail then
    local colorKey = avail.canWhisper and "online" or "offline"
    if avail.status == "WrongFaction" then colorKey = "dnd" end
    local sc = Theme.COLORS[colorKey]
    if sc and row.statusDot.SetColorTexture then
      row.statusDot:SetColorTexture(sc[1], sc[2], sc[3], sc[4])
    end
    row.statusDot:Show()
  else
    row.statusDot:Hide()
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
  -- Only show faction icon when race is unambiguously Alliance or Horde
  -- (stored factionName can be stale from BNet API for offline contacts)
  local inferredFaction = item.raceTag and (ns.Identity and ns.Identity.InferFaction and ns.Identity.InferFaction(item.raceTag)) or nil
  local factionForIcon = inferredFaction or item.factionName
  local reliableFaction = factionForIcon and Theme.FactionIcon(factionForIcon) or nil
  if reliableFaction then
    row.factionIcon:SetTexture(reliableFaction)
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

RowView.bindRow = bindRow
RowView.ROW_HEIGHT = ROW_HEIGHT

ns.ContactsListRowView = RowView
return RowView
