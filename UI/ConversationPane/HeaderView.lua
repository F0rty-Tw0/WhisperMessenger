local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

local StatusLine = ns.ConversationPaneStatusLine or require("WhisperMessenger.UI.ConversationPane.StatusLine")
local HeaderElements = ns.ConversationPaneHeaderElements
  or require("WhisperMessenger.UI.ConversationPane.HeaderElements")

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
  local HEADER_HEIGHT = options.HEADER_HEIGHT or 36

  ---------------------------------------------------------------------------
  -- Header container (56px tall, bg_header background)
  ---------------------------------------------------------------------------
  local headerFrame = HeaderElements.createHeaderFrame(factory, pane, HEADER_HEIGHT)

  ---------------------------------------------------------------------------
  -- Class icon (32x32)
  ---------------------------------------------------------------------------
  local classIconResult = HeaderElements.createClassIcon(factory, headerFrame, selectedContact)
  local classIconFrame = classIconResult.frame
  local classIcon = classIconResult.texture

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
  local headerFactionIcon = HeaderElements.createFactionIcon(headerFrame, headerName, selectedContact)

  ---------------------------------------------------------------------------
  -- Status line text (below name)
  ---------------------------------------------------------------------------
  local headerStatus = HeaderElements.createStatusLine(headerFrame, headerName, selectedContact)

  ---------------------------------------------------------------------------
  -- Status dot (overlay on class icon, bottom-right corner)
  -- Rendered as a frame so it stacks above the clipping icon frame.
  ---------------------------------------------------------------------------
  local statusDot = HeaderElements.createStatusDot(factory, headerFrame, classIconFrame, selectedContact)

  ---------------------------------------------------------------------------
  -- Header divider (1px line at bottom of header)
  ---------------------------------------------------------------------------
  local headerDivider = HeaderElements.createDivider(headerFrame)

  ---------------------------------------------------------------------------
  -- Empty state label (centered, shown when no contact selected)
  ---------------------------------------------------------------------------
  local headerEmpty = HeaderElements.createEmptyState(pane, selectedContact, factory)

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
