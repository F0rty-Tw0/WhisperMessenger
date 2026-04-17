local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Skins = ns.Skins or require("WhisperMessenger.UI.Theme.Skins")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColor = UIHelpers.applyColor
local applyColorTexture = UIHelpers.applyColorTexture
local applyPaneBackground = UIHelpers.applyPaneBackground
local createCircularIcon = UIHelpers.createCircularIcon

local StatusLine = ns.ConversationPaneStatusLine or require("WhisperMessenger.UI.ConversationPane.StatusLine")

local HeaderElements = {}

-- Creates the header container frame with background texture.
-- Returns headerFrame.
function HeaderElements.createHeaderFrame(factory, pane, HEADER_HEIGHT)
  local headerFrame = factory.CreateFrame("Frame", nil, pane)
  headerFrame:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -2)
  -- 4px right margin so the header (contact name + status line) breathes
  -- away from the pane edge and doesn't touch the chrome border. Top offset
  -- -2 aligns the contact status bar with the contact list's 2px shift.
  headerFrame:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, -2)
  headerFrame:SetHeight(HEADER_HEIGHT)

  local headerBg = headerFrame:CreateTexture(nil, "BACKGROUND")
  headerBg:SetAllPoints(headerFrame)
  local skinSpec = Skins.Get(Skins.GetActive())
  applyPaneBackground(headerBg, Theme.COLORS.bg_header, skinSpec and skinSpec.pane_header_texture)
  headerFrame.bg = headerBg
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
    headerName:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 58, -2)
    headerName:SetText(selectedContact.displayName or "")
    UIHelpers.applyClassColor(headerName, selectedContact.classTag, Theme.COLORS.text_primary)
    headerName:Show()
  else
    headerName:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 58, -2)
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

-- Creates a 4-sided border around headerFrame using full-opacity divider color
-- for stronger visibility than the base divider alpha. Returns the bottom
-- texture as the primary handle (backward compat with applyColorTexture calls)
-- with the full border table stashed on `._headerBorder` for theme refresh.
function HeaderElements.createDivider(headerFrame)
  local dividerColor = Theme.COLORS.divider or { 0.15, 0.16, 0.22, 0.60 }
  local strongColor = { dividerColor[1], dividerColor[2], dividerColor[3], 1 }
  local border = UIHelpers.createBorderBox(headerFrame, strongColor, 1, "OVERLAY")
  local primary = border and border.bottom or headerFrame:CreateTexture(nil, "OVERLAY")
  primary._headerBorder = border
  return primary
end

-- Creates the centered empty state container with label + "Start New Whisper" button.
-- Returns a Frame with ._label (FontString) and ._newWhisperButton (Button).
function HeaderElements.createEmptyState(pane, selectedContact, factory)
  local createFrame = (factory and factory.CreateFrame) or _G.CreateFrame
  local container = createFrame("Frame", nil, pane)
  container:SetPoint("CENTER", pane, "CENTER", 0, 0)
  container:SetSize(200, 50)

  local label = container:CreateFontString(nil, "OVERLAY", Theme.FONTS.empty_state)
  label:SetPoint("TOP", container, "TOP", 0, 0)
  label:SetText("Select a conversation or")
  applyColor(label, Theme.COLORS.text_secondary)
  container._label = label

  local button = createFrame("Button", nil, container)
  button:SetSize(140, 24)
  button:SetPoint("TOP", label, "BOTTOM", 0, -8)
  button:EnableMouse(true)

  local buttonBg = button:CreateTexture(nil, "BACKGROUND")
  buttonBg:SetAllPoints(button)
  local baseColor = Theme.COLORS.bg_contact_hover
  applyColorTexture(buttonBg, { baseColor[1], baseColor[2], baseColor[3], 0.35 })

  local buttonIcon = button:CreateTexture(nil, "ARTWORK")
  buttonIcon:SetSize(14, 14)
  buttonIcon:SetPoint("LEFT", button, "LEFT", 8, 0)
  buttonIcon:SetTexture("Interface\\CHATFRAME\\UI-ChatWhisperIcon")
  buttonIcon:SetDesaturated(true)
  UIHelpers.applyVertexColor(buttonIcon, Theme.COLORS.text_primary)

  local buttonText = button:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  buttonText:SetPoint("LEFT", buttonIcon, "RIGHT", 4, 0)
  buttonText:SetText("Start New Whisper")
  applyColor(buttonText, Theme.COLORS.text_primary)

  if button.SetScript then
    button:SetScript("OnEnter", function()
      local bc = Theme.COLORS.bg_contact_hover
      applyColorTexture(buttonBg, { bc[1], bc[2], bc[3], 0.75 })
    end)
    button:SetScript("OnLeave", function()
      local bc = Theme.COLORS.bg_contact_hover
      applyColorTexture(buttonBg, { bc[1], bc[2], bc[3], 0.35 })
    end)
    button:SetScript("OnClick", function()
      if type(_G.StaticPopup_Show) == "function" then
        _G.StaticPopup_Show("WHISPER_MESSENGER_START_CONVERSATION")
      end
    end)
  end

  button:Show()
  container._newWhisperButton = button
  container:SetShown(selectedContact == nil)

  return container
end

ns.ConversationPaneHeaderElements = HeaderElements

return HeaderElements
