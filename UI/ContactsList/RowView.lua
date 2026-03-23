local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local sizeValue = UIHelpers.sizeValue
local applyClassColor = UIHelpers.applyClassColor
local applyColorTexture = UIHelpers.applyColorTexture
local setTextColor = UIHelpers.setTextColor
local createCircularIcon = UIHelpers.createCircularIcon

local trace = ns.trace
if not trace then
  if type(require) == "function" then
    local ok, loaded = pcall(require, "WhisperMessenger.Core.Trace")
    if ok and loaded then
      trace = loaded
    end
  end
  if not trace then
    trace = function() end
  end
end

local RowView = {}
local ROW_HEIGHT = Theme.LAYOUT.CONTACT_ROW_HEIGHT

local function showActions(row)
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
  applyColorTexture(row.bg, Theme.COLORS.bg_secondary)

  -- Left accent bar (shown when selected)
  if row.accentBar == nil then
    row.accentBar = row:CreateTexture(nil, "BORDER")
    row.accentBar:SetSize(Theme.LAYOUT.CONTACT_ACCENT_BAR_W, ROW_HEIGHT)
    row.accentBar:SetPoint("LEFT", row, "LEFT", 0, 0)
    applyColorTexture(row.accentBar, Theme.COLORS.accent_bar)
  end
  row.accentBar:Hide()

  -- Hover / selected scripts
  if row.SetScript then
    row:SetScript("OnEnter", function()
      if not row.selected then
        applyColorTexture(row.bg, Theme.COLORS.bg_contact_hover)
      end
      showActions(row)
    end)

    row:SetScript("OnLeave", function()
      -- If the mouse moved to a child button, stay in hover state
      if row.IsMouseOver and row:IsMouseOver() then
        return
      end
      if row.selected then
        applyColorTexture(row.bg, Theme.COLORS.bg_contact_selected)
      else
        applyColorTexture(row.bg, Theme.COLORS.bg_secondary)
      end
      hideActions(row)
    end)

    row:SetScript("OnClick", function()
      if row.item ~= nil and options.onSelect then
        options.onSelect(row.item)
      end
    end)
  end

  -- Class icon (40x40, left side)
  if row.classIconFrame == nil then
    local icon = createCircularIcon(factory, row, Theme.LAYOUT.CONTACT_ICON_SIZE)
    row.classIconFrame = icon.frame
    row.classIcon = icon.texture
    row.classIconFrame:SetPoint("LEFT", row, "LEFT", Theme.LAYOUT.CONTACT_PADDING, 0)
  end
  local iconPath = Theme.ClassIcon(item.classTag)
  if iconPath then
    row.classIcon:SetTexture(iconPath)
  else
    row.classIcon:SetTexture(Theme.TEXTURES.bnet_icon)
  end

  -- Status dot (10x10, bottom-right of class icon) — rendered as a frame so
  -- it stacks above the clipping icon frame. Uses a circular texture tinted
  -- with vertex color (SetColorTexture can't be masked).
  local statusSize = Theme.LAYOUT.CONTACT_STATUS_SIZE
  local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
  if row.statusDot == nil then
    row.statusDot = factory.CreateFrame("Frame", nil, row)
    row.statusDot:SetSize(statusSize, statusSize)
    row.statusDot:SetPoint("BOTTOMRIGHT", row.classIconFrame, "BOTTOMRIGHT", 2, -2)
    if row.statusDot.SetFrameLevel and row.classIconFrame.GetFrameLevel then
      row.statusDot:SetFrameLevel(row.classIconFrame:GetFrameLevel() + 2)
    end
    row.statusDot.bg = row.statusDot:CreateTexture(nil, "OVERLAY")
    row.statusDot.bg:SetAllPoints()
    row.statusDot.bg:SetTexture(CIRCLE_TEX)
    local c = Theme.COLORS.online
    row.statusDot.bg:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  end
  local avail = item.availability
  if avail then
    local colorKey = avail.canWhisper and "online" or "offline"
    if avail.status == "WrongFaction" then
      colorKey = "dnd"
    elseif avail.status == "Away" then
      colorKey = "away"
    elseif avail.status == "Busy" then
      colorKey = "dnd"
    end
    local sc = Theme.COLORS[colorKey]
    if sc then
      row.statusDot.bg:SetVertexColor(sc[1], sc[2], sc[3], sc[4] or 1)
    end
    row.statusDot:Show()
  else
    -- No availability data: show as offline (gray) rather than hiding
    local sc = Theme.COLORS["offline"]
    if sc then
      row.statusDot.bg:SetVertexColor(sc[1], sc[2], sc[3], sc[4] or 1)
    end
    row.statusDot:Show()
  end

  -- Contact name (top line, class-colored)
  if row.title == nil then
    row.title = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_name)
    row.title:SetPoint("TOPLEFT", row.classIconFrame, "TOPRIGHT", 10, -4)
    row.title:SetWidth(parentWidth - Theme.LAYOUT.CONTACT_ICON_SIZE - Theme.LAYOUT.CONTACT_PADDING - 60)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    if row.title.SetMaxLines then
      row.title:SetMaxLines(1)
    end
  end
  row.title:SetText(item.displayName)
  applyClassColor(row.title, item.classTag, Theme.COLORS.text_primary)

  -- Faction icon (14x14, after name — positioned relative to actual text width)
  if row.factionIcon == nil then
    row.factionIcon = row:CreateTexture(nil, "ARTWORK")
    row.factionIcon:SetSize(Theme.LAYOUT.CONTACT_FACTION_SIZE, Theme.LAYOUT.CONTACT_FACTION_SIZE)
  end
  local titleTextWidth = row.title.GetStringWidth and row.title:GetStringWidth() or 0
  local titleMaxWidth = row.title.GetWidth and row.title:GetWidth() or 0
  local textW = math.min(titleTextWidth, titleMaxWidth)
  row.factionIcon:ClearAllPoints()
  row.factionIcon:SetPoint("LEFT", row.title, "LEFT", textW + 4, 0)
  -- Only show faction icon when race is unambiguously Alliance or Horde
  -- (stored factionName can be stale from BNet API for offline contacts)
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

  -- Timestamp (top-right)
  if row.timeLabel == nil then
    row.timeLabel = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_time)
    row.timeLabel:SetPoint("TOPRIGHT", row, "TOPRIGHT", -Theme.LAYOUT.CONTACT_PADDING, 0)
    row.timeLabel:SetPoint("TOP", row.title, "TOP", 0, 0)
    setTextColor(row.timeLabel, Theme.COLORS.text_secondary)
  end
  if ns.TimeFormat and ns.TimeFormat.ContactPreview then
    row.timeLabel:SetText(ns.TimeFormat.ContactPreview(item.lastActivityAt))
  else
    row.timeLabel:SetText("")
  end

  -- Preview text (bottom line, right-aligned, single line with ellipsis)
  if row.preview == nil then
    row.preview = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_preview)
    row.preview:SetPoint("BOTTOMLEFT", row.classIconFrame, "BOTTOMRIGHT", 10, 2)
    setTextColor(row.preview, Theme.COLORS.text_secondary)
    row.preview:SetWidth(parentWidth - Theme.LAYOUT.CONTACT_ICON_SIZE - Theme.LAYOUT.CONTACT_PADDING - 40)
    row.preview:SetJustifyH("LEFT")
    row.preview:SetWordWrap(false)
    if row.preview.SetMaxLines then
      row.preview:SetMaxLines(1)
    end
  end
  row.preview:SetText(item.lastPreview or "")

  -- Action buttons (pin + remove, right side, horizontal)
  local ACTION_SIZE = Theme.LAYOUT.CONTACT_ACTION_SIZE
  local ACTION_SPACING = Theme.LAYOUT.CONTACT_ACTION_SPACING

  if row.removeButton == nil then
    row.removeButton = factory.CreateFrame("Button", nil, row)
    row.removeButton:SetSize(ACTION_SIZE, ACTION_SIZE)
    row.removeButton:SetPoint("RIGHT", row, "RIGHT", -Theme.LAYOUT.CONTACT_PADDING, 0)
    if row.removeButton.EnableMouse then
      row.removeButton:EnableMouse(true)
    end
    row.removeButton.icon = row.removeButton:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_name)
    row.removeButton.icon:SetAllPoints()
    row.removeButton.icon:SetJustifyH("CENTER")
    row.removeButton.icon:SetJustifyV("MIDDLE")
    row.removeButton.icon:SetText("x")
    setTextColor(row.removeButton.icon, Theme.COLORS.action_icon)
    if row.removeButton.SetScript then
      row.removeButton:SetScript("OnEnter", function(self)
        setTextColor(self.icon, Theme.COLORS.action_remove_hover)
        -- Keep row hover state while over child button
        if not row.selected then
          applyColorTexture(row.bg, Theme.COLORS.bg_contact_hover)
        end
        showActions(row)
      end)
      row.removeButton:SetScript("OnLeave", function(self)
        setTextColor(self.icon, Theme.COLORS.action_icon)
        -- If mouse left both button and row, reset row state
        if not (row.IsMouseOver and row:IsMouseOver()) then
          if row.selected then
            applyColorTexture(row.bg, Theme.COLORS.bg_contact_selected)
          else
            applyColorTexture(row.bg, Theme.COLORS.bg_secondary)
          end
          hideActions(row)
        end
      end)
      row.removeButton:SetScript("OnClick", function()
        if row.item and options.onRemove then
          trace(
            "remove clicked",
            "key=" .. tostring(row.item.conversationKey),
            "name=" .. tostring(row.item.displayName),
            "channel=" .. tostring(row.item.channel),
            "pinned=" .. tostring(row.item.pinned)
          )
          options.onRemove(row.item)
        end
      end)
    end
  end

  if row.pinButton == nil then
    row.pinButton = factory.CreateFrame("Button", nil, row)
    row.pinButton:SetSize(ACTION_SIZE, ACTION_SIZE)
    row.pinButton:SetPoint("RIGHT", row.removeButton, "LEFT", -ACTION_SPACING, 0)
    if row.pinButton.EnableMouse then
      row.pinButton:EnableMouse(true)
    end
    row.pinButton.icon = row.pinButton:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_name)
    row.pinButton.icon:SetAllPoints()
    row.pinButton.icon:SetJustifyH("CENTER")
    row.pinButton.icon:SetJustifyV("MIDDLE")
    if row.pinButton.SetScript then
      row.pinButton:SetScript("OnEnter", function(self)
        local hoverColor = item.pinned and Theme.COLORS.action_icon_pinned or Theme.COLORS.action_icon_hover
        setTextColor(self.icon, hoverColor)
        if not row.selected then
          applyColorTexture(row.bg, Theme.COLORS.bg_contact_hover)
        end
        showActions(row)
      end)
      row.pinButton:SetScript("OnLeave", function(self)
        local baseColor = item.pinned and Theme.COLORS.action_icon_pinned or Theme.COLORS.action_icon
        setTextColor(self.icon, baseColor)
        if not (row.IsMouseOver and row:IsMouseOver()) then
          if row.selected then
            applyColorTexture(row.bg, Theme.COLORS.bg_contact_selected)
          else
            applyColorTexture(row.bg, Theme.COLORS.bg_secondary)
          end
          hideActions(row)
        end
      end)
      row.pinButton:SetScript("OnClick", function()
        if row.item and options.onPin then
          trace(
            "pin clicked",
            "key=" .. tostring(row.item.conversationKey),
            "name=" .. tostring(row.item.displayName),
            "channel=" .. tostring(row.item.channel),
            "pinned=" .. tostring(row.item.pinned)
          )
          options.onPin(row.item)
        end
      end)
    end
  end

  -- Update pin icon appearance based on pinned state
  row.pinButton.icon:SetText(item.pinned and "|" or "|")
  local pinColor = item.pinned and Theme.COLORS.action_icon_pinned or Theme.COLORS.action_icon
  setTextColor(row.pinButton.icon, pinColor)

  -- Show/hide action buttons: pinned items always show pin; others hide by default
  if item.pinned then
    row.pinButton:Show()
  else
    row.pinButton:Hide()
  end
  row.removeButton:Hide()

  -- Unread badge (bottom-right, circular)
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
