local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColor = UIHelpers.applyColor
local applyColorTexture = UIHelpers.applyColorTexture
local createCircularIcon = UIHelpers.createCircularIcon

local StatusLine = ns.ConversationPaneStatusLine or require("WhisperMessenger.UI.ConversationPane.StatusLine")

local HeaderElements = {}

-- Creates the header container frame with background texture.
-- Returns headerFrame.
function HeaderElements.createHeaderFrame(factory, pane, HEADER_HEIGHT)
  local headerFrame = factory.CreateFrame("Frame", nil, pane)
  headerFrame:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
  headerFrame:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, 0)
  headerFrame:SetHeight(HEADER_HEIGHT)

  local headerBg = headerFrame:CreateTexture(nil, "BACKGROUND")
  headerBg:SetAllPoints(headerFrame)
  applyColorTexture(headerBg, Theme.COLORS.bg_header)

  return headerFrame
end

-- Creates circular class/bnet icon inside headerFrame.
-- Returns { frame = classIconFrame, texture = classIcon }.
function HeaderElements.createClassIcon(factory, headerFrame, selectedContact)
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

  return { frame = classIconFrame, texture = classIcon }
end

-- Creates the contact name FontString anchored to classIconFrame.
-- Returns headerName FontString.
function HeaderElements.createContactName(headerFrame, selectedContact)
  local headerName = headerFrame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_name)

  if selectedContact then
    -- anchor requires classIconFrame but we accept headerFrame as anchor for simplicity;
    -- caller wires SetPoint after calling createClassIcon when needed.
    -- Here we set a simple self-relative point so the widget is valid.
    headerName:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 58, -12)
    headerName:SetText(selectedContact.displayName or "")
    UIHelpers.applyClassColor(headerName, selectedContact.classTag, Theme.COLORS.text_primary)
    headerName:Show()
  else
    headerName:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 58, -12)
    headerName:SetText("")
    headerName:Hide()
  end

  return headerName
end

-- Creates the faction icon texture (16x16) positioned right of headerName.
-- Returns headerFactionIcon texture.
function HeaderElements.createFactionIcon(headerFrame, headerName, selectedContact)
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

  return headerFactionIcon
end

-- Creates the status line FontString below headerName.
-- Returns headerStatus FontString.
function HeaderElements.createStatusLine(headerFrame, headerName, selectedContact)
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

  return headerStatus
end

-- Creates the status dot frame overlaying the class icon (bottom-right corner).
-- Returns statusDot frame.
function HeaderElements.createStatusDot(factory, headerFrame, classIconFrame, selectedContact)
  local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
  local dotSize = Theme.LAYOUT.HEADER_STATUS_DOT_SIZE
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

  return statusDot
end

-- Creates the 1px divider line at the bottom of headerFrame.
-- Returns headerDivider texture.
function HeaderElements.createDivider(headerFrame)
  local headerDivider = headerFrame:CreateTexture(nil, "BACKGROUND")
  headerDivider:SetPoint("BOTTOMLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
  headerDivider:SetPoint("BOTTOMRIGHT", headerFrame, "BOTTOMRIGHT", 0, 0)
  headerDivider:SetHeight(1)
  applyColorTexture(headerDivider, Theme.COLORS.divider)

  return headerDivider
end

-- Creates the centered "Select a conversation" empty state label on pane.
-- Returns headerEmpty FontString.
function HeaderElements.createEmptyState(pane, selectedContact)
  local headerEmpty = pane:CreateFontString(nil, "OVERLAY", Theme.FONTS.empty_state)
  headerEmpty:SetPoint("CENTER", pane, "CENTER", 0, 0)
  headerEmpty:SetText("Select a conversation")
  applyColor(headerEmpty, Theme.COLORS.text_secondary)
  headerEmpty:SetShown(selectedContact == nil)

  return headerEmpty
end

ns.ConversationPaneHeaderElements = HeaderElements

return HeaderElements
