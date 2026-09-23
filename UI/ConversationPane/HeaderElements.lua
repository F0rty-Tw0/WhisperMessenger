local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local applyColor = UIHelpers.applyColor
local applyColorTexture = UIHelpers.applyColorTexture
local createCircularIcon = UIHelpers.createCircularIcon

local StatusLine = ns.ConversationPaneStatusLine or require("WhisperMessenger.UI.ConversationPane.StatusLine")

local HeaderElements = {}

-- Vertical gaps between the header's stacked text rows (name -> status -> detail).
local STATUS_LINE_GAP = 2
local STATUS_DETAIL_GAP = 5

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
  applyColorTexture(headerBg, Theme.COLORS.bg_header)
  headerFrame.bg = headerBg
  return headerFrame
end

function HeaderElements.createClassIcon(factory, headerFrame, selectedContact)
  local headerIcon = createCircularIcon(factory, headerFrame, Theme.LAYOUT.HEADER_ICON_SIZE)
  local classIconFrame = headerIcon.frame
  local classIcon = headerIcon.texture
  classIconFrame:SetPoint("LEFT", headerFrame, "LEFT", Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER, 0)

  local iconPath = Theme.ClassIcon(selectedContact and selectedContact.classTag)
  if iconPath then
    classIcon:SetTexture(iconPath)
  else
    classIcon:SetTexture(Theme.TEXTURES.bnet_icon)
  end

  return { frame = classIconFrame, texture = classIcon }
end

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

function HeaderElements.createStatusLine(headerFrame, headerName, selectedContact)
  local headerStatus = headerFrame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_status)
  headerStatus:SetJustifyH("LEFT")
  if type(headerStatus.SetWordWrap) == "function" then
    headerStatus:SetWordWrap(false)
  end
  if type(headerStatus.SetMaxLines) == "function" then
    headerStatus:SetMaxLines(1)
  end
  headerStatus:SetPoint("TOPLEFT", headerName, "BOTTOMLEFT", 0, -STATUS_LINE_GAP)
  applyColor(headerStatus, Theme.COLORS.text_secondary)

  if selectedContact then
    local line1 = StatusLine.Build(selectedContact)
    headerStatus:SetText(line1)
    headerStatus:Show()
  else
    headerStatus:SetText("")
    headerStatus:Hide()
  end

  return headerStatus
end

function HeaderElements.createStatusDetail(headerFrame, headerStatus)
  local headerStatusDetail = headerFrame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_status)
  headerStatusDetail:SetJustifyH("LEFT")
  if type(headerStatusDetail.SetWordWrap) == "function" then
    headerStatusDetail:SetWordWrap(false)
  end
  if type(headerStatusDetail.SetMaxLines) == "function" then
    headerStatusDetail:SetMaxLines(1)
  end
  headerStatusDetail:SetPoint("TOPLEFT", headerStatus, "BOTTOMLEFT", 0, -STATUS_DETAIL_GAP)
  applyColor(headerStatusDetail, Theme.COLORS.text_secondary)
  headerStatusDetail:SetText("")
  headerStatusDetail:Hide()

  return headerStatusDetail
end

function HeaderElements.createStatusDot(factory, headerFrame, classIconFrame, selectedContact)
  local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
  local dotSize = Theme.LAYOUT.HEADER_STATUS_DOT_SIZE
  local statusDot = factory.CreateFrame("Frame", nil, headerFrame)
  statusDot:SetSize(dotSize, dotSize)
  statusDot:SetPoint("BOTTOMRIGHT", classIconFrame, "BOTTOMRIGHT", Theme.LAYOUT.STATUS_DOT_CORNER_OFFSET, -Theme.LAYOUT.STATUS_DOT_CORNER_OFFSET)
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

-- Creates the header's border box (applyDividerTheme shows only the bottom
-- hairline). Returns the bottom texture as the primary handle (backward
-- compat with applyColorTexture calls) with the full border table stashed on
-- `._headerBorder` for theme refresh.
function HeaderElements.createDivider(headerFrame)
  local border = UIHelpers.createBorderBox(headerFrame, nil, 1, "OVERLAY")
  local primary = border and border.bottom or headerFrame:CreateTexture(nil, "OVERLAY")
  primary._headerBorder = border
  primary._headerSheen = UIHelpers.createSheen(headerFrame)
  HeaderElements.applyDividerTheme(primary)
  return primary
end

local BOTTOM_ONLY = { bottom = true }

-- Repaint the header border (only the bottom hairline shows) and its gloss
-- sheen.
function HeaderElements.applyDividerTheme(primary)
  if primary._headerSheen then
    UIHelpers.applySheen(primary._headerSheen)
  end
  local color = Theme.COLORS.divider or { 0.15, 0.16, 0.22, 0.60 }
  local border = primary._headerBorder
  if border == nil then
    applyColorTexture(primary, color)
    return
  end
  UIHelpers.applyBorderBoxColor(border, color)
  UIHelpers.setBorderEdgesShown(border, BOTTOM_ONLY)
end

-- Empty-state layout (shown when no conversation is selected).
local EMPTY_LOGO_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\icon.png"
local EMPTY_WIDTH = 280
local EMPTY_HEIGHT = 170
local EMPTY_LOGO_SIZE = 48
local EMPTY_SUBTITLE_WIDTH = 260
local EMPTY_BUTTON_WIDTH = 150
local EMPTY_BUTTON_HEIGHT = 24
local NATIVE_BUTTON_HEIGHT = 22
local GROUPS_SUBTITLE_KEY = "Party, raid, instance and guild chats show up here. Join a group or pick a chat on the left."

local function paintEmptyButtonBg(buttonBg, hovered)
  applyColorTexture(buttonBg, UIHelpers.hoverButtonFill(Theme.COLORS.bg_contact_hover, hovered))
end

-- nativeChrome: Native WoW HUD -> Blizzard button art.
function HeaderElements.createEmptyState(pane, selectedContact, factory, nativeChrome)
  local createFrame = (factory and factory.CreateFrame) or _G.CreateFrame
  local container = createFrame("Frame", nil, pane)
  container:SetPoint("CENTER", pane, "CENTER", 0, 0)
  container:SetSize(EMPTY_WIDTH, EMPTY_HEIGHT)

  local logo = container:CreateTexture(nil, "ARTWORK")
  logo:SetSize(EMPTY_LOGO_SIZE, EMPTY_LOGO_SIZE)
  logo:SetPoint("TOP", container, "TOP", 0, 0)
  logo:SetTexture(EMPTY_LOGO_TEXTURE)

  local title = container:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_name)
  title:SetPoint("TOP", logo, "BOTTOM", 0, -12)

  local subtitle = container:CreateFontString(nil, "OVERLAY", Theme.FONTS.empty_state)
  subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)
  subtitle:SetWidth(EMPTY_SUBTITLE_WIDTH)
  subtitle:SetJustifyH("CENTER")
  if type(subtitle.SetWordWrap) == "function" then
    subtitle:SetWordWrap(true)
  end

  -- Native WoW HUD: Blizzard red-gold UIPanelButtonTemplate (label via the
  -- button's own SetText, no child keys). Falls back to the modern button
  -- when the template is unavailable.
  local nativeButton = nativeChrome
    and UIHelpers.createTemplatedFrame({ CreateFrame = createFrame }, "Button", nil, container, "UIPanelButtonTemplate")
  local button, buttonBg, buttonIcon, buttonText
  if nativeButton then
    button = nativeButton
    button:SetSize(EMPTY_BUTTON_WIDTH, NATIVE_BUTTON_HEIGHT)
    button:SetPoint("TOP", subtitle, "BOTTOM", 0, -16)
  else
    button = createFrame("Button", nil, container)
    button:SetSize(EMPTY_BUTTON_WIDTH, EMPTY_BUTTON_HEIGHT)
    button:SetPoint("TOP", subtitle, "BOTTOM", 0, -16)
    button:EnableMouse(true)

    buttonBg = button:CreateTexture(nil, "BACKGROUND")
    buttonBg:SetAllPoints(button)

    -- Same glyph as the title-bar New Whisper button.
    buttonIcon = button:CreateTexture(nil, "ARTWORK")
    buttonIcon:SetSize(Theme.LAYOUT.CHROME_BUTTON_ICON_SIZE, Theme.LAYOUT.CHROME_BUTTON_ICON_SIZE)
    buttonIcon:SetPoint("LEFT", button, "LEFT", 8, 0)
    buttonIcon:SetTexture(Theme.TEXTURES.title_new_whisper_icon)
    buttonIcon:SetDesaturated(true)

    buttonText = button:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
    buttonText:SetPoint("LEFT", buttonIcon, "RIGHT", 4, 0)

    if button.SetScript then
      button:SetScript("OnEnter", function()
        paintEmptyButtonBg(buttonBg, true)
      end)
      button:SetScript("OnLeave", function()
        paintEmptyButtonBg(buttonBg, false)
      end)
    end
  end

  if button.SetScript then
    button:SetScript("OnClick", function()
      if type(_G.StaticPopup_Show) == "function" then
        _G.StaticPopup_Show("WHISPER_MESSENGER_START_CONVERSATION")
      end
    end)
  end

  button:Show()
  -- "groups" swaps to group-chat copy; the Start New Whisper button is
  -- whisper-only, so it hides there.
  local mode = "whispers"
  container.setLanguage = function()
    if mode == "groups" then
      title:SetText(Localization.Text("Group Chats"))
      subtitle:SetText(Localization.Text(GROUPS_SUBTITLE_KEY))
    else
      title:SetText(Localization.Text("Welcome to WhisperMessenger"))
      subtitle:SetText(Localization.Text("Pick a conversation on the left, or start a new one."))
    end
    if buttonText then
      buttonText:SetText(Localization.Text("Start New Whisper"))
    else
      button:SetText(Localization.Text("Start New Whisper"))
    end
  end
  container.applyTheme = function()
    applyColor(title, Theme.COLORS.text_primary)
    applyColor(subtitle, Theme.COLORS.text_secondary)
    -- The Blizzard button keeps its own art and text colour.
    if buttonText then
      applyColor(buttonText, Theme.COLORS.text_primary)
      UIHelpers.applyVertexColor(buttonIcon, Theme.COLORS.text_primary)
      paintEmptyButtonBg(buttonBg, false)
    end
  end
  container.setMode = function(nextMode)
    mode = nextMode == "groups" and "groups" or "whispers"
    button:SetShown(mode ~= "groups")
    container.setLanguage()
  end
  container.setLanguage()
  container.applyTheme()
  container:SetShown(selectedContact == nil)

  return container
end

ns.ConversationPaneHeaderElements = HeaderElements

return HeaderElements
