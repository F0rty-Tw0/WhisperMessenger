local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColor = UIHelpers.applyColor
local applyClassColor = UIHelpers.applyClassColor
local applyColorTexture = UIHelpers.applyColorTexture
local applyVertexColor = UIHelpers.applyVertexColor
local createCircularIcon = UIHelpers.createCircularIcon

local StatusLine = ns.ConversationPaneStatusLine or require("WhisperMessenger.UI.ConversationPane.StatusLine")

local HeaderView = {}

local function headerTextFor(selectedContact)
  if selectedContact and selectedContact.displayName then
    return selectedContact.displayName
  end

  return "No conversation selected"
end

-- Create the header widgets inside pane.
-- Returns a table with all header widget references.
function HeaderView.Create(factory, pane, selectedContact, options)
  options = options or {}
  local HEADER_HEIGHT = options.HEADER_HEIGHT or 56

  ---------------------------------------------------------------------------
  -- Header container (56px tall, bg_header background)
  ---------------------------------------------------------------------------
  local headerFrame = factory.CreateFrame("Frame", nil, pane)
  headerFrame:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
  headerFrame:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, 0)
  headerFrame:SetHeight(HEADER_HEIGHT)

  local headerBg = headerFrame:CreateTexture(nil, "BACKGROUND")
  headerBg:SetAllPoints(headerFrame)
  applyColorTexture(headerBg, Theme.COLORS.bg_header)

  ---------------------------------------------------------------------------
  -- Class icon (32x32)
  ---------------------------------------------------------------------------
  local headerIcon = createCircularIcon(factory, headerFrame, Theme.LAYOUT.HEADER_ICON_SIZE)
  local classIconFrame = headerIcon.frame
  local classIcon = headerIcon.texture
  classIconFrame:SetPoint("LEFT", headerFrame, "LEFT", 16, 0)

  local iconPath = Theme.ClassIcon(selectedContact and selectedContact.classTag)
  if iconPath then
    classIcon:SetTexture(iconPath)
  else
    classIcon:SetTexture(Theme.TEXTURES.bnet_icon)
  end

  ---------------------------------------------------------------------------
  -- Contact name (class-colored, GameFontHighlightLarge)
  ---------------------------------------------------------------------------
  local headerName = headerFrame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_name)
  headerName:SetPoint("TOPLEFT", classIconFrame, "TOPRIGHT", 10, -4)

  if selectedContact then
    headerName:SetText(selectedContact.displayName or "")
    UIHelpers.applyClassColor(headerName, selectedContact.classTag, Theme.COLORS.text_primary)
    headerName:Show()
  else
    headerName:SetText("")
    headerName:Hide()
  end

  ---------------------------------------------------------------------------
  -- Faction icon (16x16, right of name)
  ---------------------------------------------------------------------------
  local headerFactionIcon = headerFrame:CreateTexture(nil, "ARTWORK")
  headerFactionIcon:SetSize(16, 16)
  headerFactionIcon:SetPoint("LEFT", headerName, "RIGHT", 6, 0)
  headerFactionIcon:Hide()

  if selectedContact and selectedContact.factionName then
    local factionPath = Theme.FactionIcon(selectedContact.factionName)
    if factionPath then
      headerFactionIcon:SetTexture(factionPath)
      headerFactionIcon:Show()
    end
  end

  ---------------------------------------------------------------------------
  -- Status line text (below name)
  ---------------------------------------------------------------------------
  local headerStatus = headerFrame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_status)
  headerStatus:SetPoint("TOPLEFT", headerName, "BOTTOMLEFT", 0, -2)
  applyColor(headerStatus, Theme.COLORS.text_secondary)

  if selectedContact then
    headerStatus:SetText(StatusLine.Build(selectedContact))
    headerStatus:Show()
  else
    headerStatus:SetText("")
    headerStatus:Hide()
  end

  ---------------------------------------------------------------------------
  -- Status dot (overlay on class icon, bottom-right corner)
  -- Rendered as a frame so it stacks above the clipping icon frame.
  ---------------------------------------------------------------------------
  local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
  local dotSize = Theme.LAYOUT.HEADER_STATUS_DOT_SIZE -- 8
  local statusDot = factory.CreateFrame("Frame", nil, headerFrame)
  statusDot:SetSize(dotSize, dotSize)
  statusDot:SetPoint("BOTTOMRIGHT", classIconFrame, "BOTTOMRIGHT", 2, -2)
  if statusDot.SetFrameLevel and classIconFrame.GetFrameLevel then
    statusDot:SetFrameLevel(classIconFrame:GetFrameLevel() + 2)
  end
  statusDot.bg = statusDot:CreateTexture(nil, "OVERLAY")
  statusDot.bg:SetAllPoints()
  statusDot.bg:SetTexture(CIRCLE_TEX)
  local dotColor = Theme.COLORS.online
  statusDot.bg:SetVertexColor(dotColor[1], dotColor[2], dotColor[3], dotColor[4] or 1)
  statusDot:SetShown(selectedContact ~= nil)

  ---------------------------------------------------------------------------
  -- Header divider (1px line at bottom of header)
  ---------------------------------------------------------------------------
  local headerDivider = headerFrame:CreateTexture(nil, "BACKGROUND")
  headerDivider:SetPoint("BOTTOMLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
  headerDivider:SetPoint("BOTTOMRIGHT", headerFrame, "BOTTOMRIGHT", 0, 0)
  headerDivider:SetHeight(1)
  applyColorTexture(headerDivider, Theme.COLORS.divider)

  ---------------------------------------------------------------------------
  -- Empty state label (centered, shown when no contact selected)
  ---------------------------------------------------------------------------
  local headerEmpty = pane:CreateFontString(nil, "OVERLAY", Theme.FONTS.empty_state)
  headerEmpty:SetPoint("CENTER", pane, "CENTER", 0, 0)
  headerEmpty:SetText("Select a conversation")
  applyColor(headerEmpty, Theme.COLORS.text_secondary)
  headerEmpty:SetShown(selectedContact == nil)

  return {
    headerFrame = headerFrame,
    headerClassIcon = classIcon,
    headerClassIconFrame = classIconFrame,
    headerName = headerName,
    headerFactionIcon = headerFactionIcon,
    headerStatus = headerStatus,
    headerStatusDot = statusDot,
    headerDivider = headerDivider,
    headerEmpty = headerEmpty,
  }
end

-- Update all header widgets to reflect the current contact and status.
function HeaderView.Refresh(view, selectedContact, _conversation, status)
  if view.headerFrame then
    local hasContact = selectedContact ~= nil

    -- Update class icon
    if view.headerClassIcon then
      local iconPath = Theme.ClassIcon(selectedContact and selectedContact.classTag)
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

    -- Update contact name with class color
    if view.headerName then
      if hasContact then
        view.headerName:SetText(selectedContact.displayName or "")
        UIHelpers.applyClassColor(view.headerName, selectedContact.classTag, Theme.COLORS.text_primary)
        view.headerName:Show()
      else
        view.headerName:SetText("")
        view.headerName:Hide()
      end
    end

    -- Update status line and dot color from availability
    local statusText, dotColorKey = StatusLine.Build(selectedContact, status)
    if view.headerStatus then
      if hasContact then
        view.headerStatus:SetText(statusText)
        view.headerStatus:Show()
      else
        view.headerStatus:SetText("")
        view.headerStatus:Hide()
      end
    end

    if view.headerStatusDot then
      if hasContact and dotColorKey and Theme.COLORS[dotColorKey] then
        local dc = Theme.COLORS[dotColorKey]
        if view.headerStatusDot.bg and view.headerStatusDot.bg.SetVertexColor then
          view.headerStatusDot.bg:SetVertexColor(dc[1], dc[2], dc[3], dc[4] or 1)
        end
        view.headerStatusDot:SetShown(true)
      else
        view.headerStatusDot:SetShown(false)
      end
    end

    -- Update faction icon
    if view.headerFactionIcon then
      local factionPath = hasContact and selectedContact.factionName and Theme.FactionIcon(selectedContact.factionName)
        or nil
      if factionPath then
        view.headerFactionIcon:SetTexture(factionPath)
        view.headerFactionIcon:Show()
      else
        view.headerFactionIcon:Hide()
      end
    end

    -- Update empty state visibility
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
