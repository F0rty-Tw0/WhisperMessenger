local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Loader = ns.Loader or require("WhisperMessenger.Core.Loader")
local loadModule = Loader.LoadModule

local Theme = loadModule("WhisperMessenger.UI.Theme", "Theme")
local UIHelpers = loadModule("WhisperMessenger.UI.Helpers", "UIHelpers")
local applyColor = UIHelpers.applyColor

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
  local hc = Theme.COLORS.bg_header
  headerBg:SetColorTexture(hc[1], hc[2], hc[3], hc[4] or 1)

  ---------------------------------------------------------------------------
  -- Class icon (32x32)
  ---------------------------------------------------------------------------
  local classIcon = headerFrame:CreateTexture(nil, "ARTWORK")
  local iconSize = Theme.LAYOUT.HEADER_ICON_SIZE -- 32
  classIcon:SetSize(iconSize, iconSize)
  classIcon:SetPoint("LEFT", headerFrame, "LEFT", 16, 0)

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
  headerName:SetPoint("TOPLEFT", classIcon, "TOPRIGHT", 10, -4)

  if selectedContact then
    headerName:SetText(selectedContact.displayName or "")
    local classTag = selectedContact.classTag
    if classTag and _G.RAID_CLASS_COLORS then
      local classColor = _G.RAID_CLASS_COLORS[string.upper(classTag)]
      if classColor then
        if classColor.r then
          headerName:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
        elseif type(classColor[1]) == "number" then
          headerName:SetTextColor(classColor[1], classColor[2], classColor[3], 1)
        end
      else
        applyColor(headerName, Theme.COLORS.text_primary)
      end
    else
      applyColor(headerName, Theme.COLORS.text_primary)
    end
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
  -- Status dot (8x8) anchored just left of status text
  ---------------------------------------------------------------------------
  local statusDot = headerFrame:CreateTexture(nil, "ARTWORK")
  local dotSize = Theme.LAYOUT.HEADER_STATUS_DOT_SIZE -- 8
  statusDot:SetSize(dotSize, dotSize)
  statusDot:SetPoint("RIGHT", headerStatus, "LEFT", -4, 0)
  statusDot:SetTexture("Interface\\COMMON\\Indicator-Gray")
  local oc = Theme.COLORS.online
  statusDot:SetVertexColor(oc[1], oc[2], oc[3], oc[4] or 1)
  statusDot:SetShown(selectedContact ~= nil)

  ---------------------------------------------------------------------------
  -- Header divider (1px line at bottom of header)
  ---------------------------------------------------------------------------
  local headerDivider = headerFrame:CreateTexture(nil, "BACKGROUND")
  headerDivider:SetPoint("BOTTOMLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
  headerDivider:SetPoint("BOTTOMRIGHT", headerFrame, "BOTTOMRIGHT", 0, 0)
  headerDivider:SetHeight(1)
  local dc = Theme.COLORS.divider
  headerDivider:SetColorTexture(dc[1], dc[2], dc[3], dc[4] or 1)

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
      view.headerClassIcon:SetShown(hasContact)
    end

    -- Update contact name with class color
    if view.headerName then
      if hasContact then
        view.headerName:SetText(selectedContact.displayName or "")
        local classTag = selectedContact.classTag
        if classTag and _G.RAID_CLASS_COLORS then
          local classColor = _G.RAID_CLASS_COLORS[string.upper(classTag)]
          if classColor then
            if classColor.r then
              view.headerName:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
            elseif type(classColor[1]) == "number" then
              view.headerName:SetTextColor(classColor[1], classColor[2], classColor[3], 1)
            end
          else
            applyColor(view.headerName, Theme.COLORS.text_primary)
          end
        else
          applyColor(view.headerName, Theme.COLORS.text_primary)
        end
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
        local dotColor = Theme.COLORS[dotColorKey]
        view.headerStatusDot:SetVertexColor(dotColor[1], dotColor[2], dotColor[3], dotColor[4] or 1)
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
