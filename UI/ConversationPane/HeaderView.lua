local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

local StatusLine = ns.ConversationPaneStatusLine or require("WhisperMessenger.UI.ConversationPane.StatusLine")
local HeaderElements = ns.ConversationPaneHeaderElements or require("WhisperMessenger.UI.ConversationPane.HeaderElements")
local AddonBadge = ns.ConversationPaneAddonBadge or require("WhisperMessenger.UI.ConversationPane.AddonBadge")
local GroupHeaderViewModel = ns.ConversationPaneGroupHeaderViewModel or require("WhisperMessenger.UI.ConversationPane.GroupHeaderViewModel")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local fitTextWithEllipsis = UIHelpers.fitTextWithEllipsis

local HEADER_STATUS_RIGHT_INSET = 8
-- Top inset of the name row; the two status rows hang below it.
local HEADER_NAME_TOP_INSET = 7

local function fitOneLine(fontString, fullText, width)
  fontString:SetWidth(width)
  fontString:SetText(fitTextWithEllipsis(fontString, fullText, width))
end

local function refitStatus(view)
  if view == nil then
    return
  end

  local statusWidth
  if type(view._headerWidth) == "number" then
    statusWidth =
      math.max(0, view._headerWidth - Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER - Theme.LAYOUT.HEADER_ICON_SIZE - 10 - HEADER_STATUS_RIGHT_INSET)
  end

  local headerStatus = view.headerStatus
  if headerStatus ~= nil and view._headerStatusVisible == true then
    local statusText = view._headerStatusFullText or ""
    if statusWidth == nil then
      headerStatus:SetText(statusText)
    else
      fitOneLine(headerStatus, statusText, statusWidth)
    end
  end

  local headerStatusDetail = view.headerStatusDetail
  if headerStatusDetail ~= nil and view._headerStatusDetailVisible == true then
    local detailText = view._headerStatusDetailFullText or ""
    if statusWidth == nil then
      headerStatusDetail:SetText(detailText)
    else
      fitOneLine(headerStatusDetail, detailText, statusWidth)
    end
  end
end

local HeaderView = {}

-- Resolve and cache the current player's class tag for group-chat headers.
-- Groups are tinted with the player's own class color so the conversation
-- reads as yours rather than being colored by a sender's class.
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

local function headerTextFor(selectedContact)
  if selectedContact and selectedContact.displayName then
    return selectedContact.displayName
  end

  return Localization.Text("No conversation selected")
end

function HeaderView.Create(factory, pane, selectedContact, options)
  options = options or {}
  local HEADER_HEIGHT = options.HEADER_HEIGHT or 36

  local headerFrame = HeaderElements.createHeaderFrame(factory, pane, HEADER_HEIGHT)

  local classIconResult = HeaderElements.createClassIcon(factory, headerFrame, selectedContact)
  local classIconFrame = classIconResult.frame
  local classIcon = classIconResult.texture

  local headerName = headerFrame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_name)
  -- Anchored to the header frame (not the class icon) so three text rows
  -- (name, status line, status detail) fit within HEADER_HEIGHT.
  headerName:SetPoint(
    "TOPLEFT",
    headerFrame,
    "TOPLEFT",
    Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER + Theme.LAYOUT.HEADER_ICON_SIZE + 10,
    -HEADER_NAME_TOP_INSET
  )

  if selectedContact then
    headerName:SetText(selectedContact.displayName or "")
    UIHelpers.applyClassColor(headerName, selectedContact.classTag, Theme.COLORS.text_primary)
    headerName:Show()
  else
    headerName:SetText("")
    headerName:Hide()
  end

  local headerFactionIcon = HeaderElements.createFactionIcon(headerFrame, headerName, selectedContact)

  local headerStatus = HeaderElements.createStatusLine(headerFrame, headerName, selectedContact)

  local headerStatusDetail = HeaderElements.createStatusDetail(headerFrame, headerStatus)

  local headerAddonBadgeButton, headerAddonBadge = AddonBadge.createAddonBadge(factory, headerFrame, headerFactionIcon)

  local statusDot = HeaderElements.createStatusDot(factory, headerFrame, classIconFrame, selectedContact)

  local headerDivider = HeaderElements.createDivider(headerFrame)

  local headerEmpty = HeaderElements.createEmptyState(pane, selectedContact, factory)

  -- Channel chip: small label shown for group conversations to the right of
  -- the header name. Hidden for whisper conversations.
  local headerChannelChip = headerFrame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  headerChannelChip:SetPoint("LEFT", headerName, "RIGHT", 6, 0)
  UIHelpers.applyColor(headerChannelChip, Theme.COLORS.text_secondary)
  headerChannelChip:SetText("")
  headerChannelChip:Hide()

  return {
    headerFrame = headerFrame,
    headerClassIcon = classIcon,
    headerClassIconFrame = classIconFrame,
    headerName = headerName,
    headerFactionIcon = headerFactionIcon,
    headerStatus = headerStatus,
    headerStatusDetail = headerStatusDetail,
    headerAddonBadge = headerAddonBadge,
    headerAddonBadgeButton = headerAddonBadgeButton,
    headerStatusDot = statusDot,
    headerDivider = headerDivider,
    headerEmpty = headerEmpty,
    headerChannelChip = headerChannelChip,
  }
end

function HeaderView.SetLanguage(view)
  if view and view.headerEmpty and view.headerEmpty.setLanguage then
    view.headerEmpty.setLanguage()
  end
  AddonBadge.SetLanguage(view)
end

function HeaderView.Relayout(view, width)
  if view == nil then
    return
  end

  view._headerWidth = width or 0
  refitStatus(view)
end

function HeaderView.Refresh(view, selectedContact, conversation, status)
  if view.headerFrame then
    local hasContact = selectedContact ~= nil
    local vm = GroupHeaderViewModel.Build(selectedContact, conversation)

    if view.headerClassIcon then
      local iconPath
      if vm and vm.isGroup then
        iconPath = Theme.ChannelIcon and Theme.ChannelIcon(selectedContact and selectedContact.channel) or nil
      else
        iconPath = Theme.ClassIcon(selectedContact and selectedContact.classTag)
      end
      if iconPath then
        view.headerClassIcon:SetTexture(iconPath)
      else
        view.headerClassIcon:SetTexture(Theme.TEXTURES.bnet_icon)
      end
    end
    if view.headerClassIconFrame and view.headerClassIconFrame.SetShown then
      view.headerClassIconFrame:SetShown(hasContact)
    elseif view.headerClassIcon then
      view.headerClassIcon:SetShown(hasContact)
    end

    if view.headerName then
      if hasContact then
        local title = (vm and vm.title) or (selectedContact.displayName or "")
        view.headerName:SetText(title)
        if vm and vm.isGroup then
          local groupClassTag = selectedContact.ownerClassTag
          if groupClassTag == nil and not selectedContact.ownerProfileId then
            groupClassTag = playerClassTag()
          end
          UIHelpers.applyClassColor(view.headerName, groupClassTag, Theme.COLORS.text_primary)
        else
          UIHelpers.applyClassColor(view.headerName, selectedContact.classTag, Theme.COLORS.text_primary)
        end
        view.headerName:Show()
      else
        view.headerName:SetText("")
        view.headerName:Hide()
      end
    end

    -- Channel chip (groups only) — stored on the view for theme refresh
    if view.headerChannelChip then
      local chip = vm and vm.channelChip or nil
      if chip and chip ~= "" then
        view.headerChannelChip:SetText("[" .. chip .. "]")
        view.headerChannelChip:Show()
      else
        view.headerChannelChip:SetText("")
        view.headerChannelChip:Hide()
      end
    end

    local showStatusLine = hasContact and (vm == nil or vm.showStatusLine)
    local line1, line2, dotColorKey = StatusLine.Build(selectedContact, status)
    view._headerStatusFullText = line1 or ""
    view._headerStatusVisible = showStatusLine
    view._headerStatusDetailFullText = line2 or ""
    view._headerStatusDetailVisible = showStatusLine and line2 ~= ""
    if view.headerStatus then
      if showStatusLine then
        UIHelpers.applyColor(view.headerStatus, Theme.COLORS.text_secondary)
        view.headerStatus:Show()
      else
        view.headerStatus:SetText("")
        view.headerStatus:Hide()
      end
    end
    if view.headerStatusDetail then
      if view._headerStatusDetailVisible then
        UIHelpers.applyColor(view.headerStatusDetail, Theme.COLORS.text_secondary)
        view.headerStatusDetail:Show()
      else
        view.headerStatusDetail:SetText("")
        view.headerStatusDetail:Hide()
      end
    end
    refitStatus(view)

    local showDot = hasContact and (vm == nil or vm.showPresenceDot)
    if view.headerStatusDot then
      if showDot and dotColorKey and Theme.COLORS[dotColorKey] then
        local dc = Theme.COLORS[dotColorKey]
        if view.headerStatusDot.bg and view.headerStatusDot.bg.SetVertexColor then
          view.headerStatusDot.bg:SetVertexColor(dc[1], dc[2], dc[3], dc[4] or 1)
        end
        view.headerStatusDot:SetShown(true)
      else
        view.headerStatusDot:SetShown(false)
      end
    end

    local showFaction = hasContact and (vm == nil or vm.showFactionIcon)
    if view.headerFactionIcon then
      local factionPath = showFaction and selectedContact.factionName and Theme.FactionIcon(selectedContact.factionName) or nil
      if factionPath then
        view.headerFactionIcon:SetTexture(factionPath)
        view.headerFactionIcon:Show()
      else
        view.headerFactionIcon:Hide()
      end
    end

    AddonBadge.Refresh(view, selectedContact, conversation)

    if view.headerEmpty then
      view.headerEmpty:SetShown(not hasContact)
    end
  else
    -- Fallback: legacy header (should not happen after Create, but kept for safety)
    if view.header then
      view.header:SetText(headerTextFor(selectedContact))
    end
  end
end

ns.ConversationPaneHeaderView = HeaderView

return HeaderView
