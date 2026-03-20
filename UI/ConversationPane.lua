local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationPane = {}
local TRANSCRIPT_LINE_HEIGHT = 16
local TRANSCRIPT_SCROLL_STEP = 24
local TRANSCRIPT_BOTTOM_GAP = 56

local Loader = ns.Loader or require("WhisperMessenger.Core.Loader")
local loadModule = Loader.LoadModule

local ScrollView = loadModule("WhisperMessenger.UI.ScrollView", "ScrollView")
local Theme = loadModule("WhisperMessenger.UI.Theme", "Theme")
local ChatBubble = loadModule("WhisperMessenger.UI.ChatBubble", "ChatBubble")

local function formatMessage(message)
  if message.kind == "system" then
    return "[System] " .. (message.text or "")
  end

  if message.direction == "out" then
    return "You: " .. (message.text or "")
  end

  return message.text or ""
end

local function headerTextFor(selectedContact)
  if selectedContact and selectedContact.displayName then
    return selectedContact.displayName
  end

  return "No conversation selected"
end

local UIHelpers = loadModule("WhisperMessenger.UI.Helpers", "UIHelpers")
local sizeValue = UIHelpers.sizeValue
local applyColor = UIHelpers.applyColor

local function transcriptContentHeight(transcript)
  if transcript.text and type(transcript.text.GetStringHeight) == "function" then
    local measuredHeight = transcript.text:GetStringHeight()
    if type(measuredHeight) == "number" and measuredHeight > 0 then
      return measuredHeight
    end
  end

  return math.max(#(transcript.lines or {}), 1) * TRANSCRIPT_LINE_HEIGHT
end

local function pointValue(target, fallback)
  if target and target.point ~= nil then
    return target.point
  end

  if target and type(target.GetPoint) == "function" then
    local point, relativeTo, relativePoint, offsetX, offsetY = target:GetPoint(1)
    if point ~= nil then
      return { point, relativeTo, relativePoint, offsetX, offsetY }
    end
  end

  return fallback
end

local function updateTranscriptLayout(transcript, snapToEnd)
  local scrollFrame = transcript.scrollFrame or transcript
  local appliedWidth = nil

  for _ = 1, 3 do
    local transcriptWidth = sizeValue(scrollFrame, "GetWidth", "width", 0)

    if transcript.text and transcript.text.SetWidth and transcriptWidth ~= appliedWidth then
      transcript.text:SetWidth(transcriptWidth)
      appliedWidth = transcriptWidth
    end

    ScrollView.RefreshMetrics(transcript, transcriptContentHeight(transcript), snapToEnd == true)

    local settledWidth = sizeValue(scrollFrame, "GetWidth", "width", transcriptWidth)
    if transcript.text == nil or transcript.text.SetWidth == nil or settledWidth == appliedWidth then
      break
    end
  end

  transcript.point = pointValue(scrollFrame, transcript.point)
  transcript.width = sizeValue(scrollFrame, "GetWidth", "width", transcript.width or 0)
  transcript.height = sizeValue(scrollFrame, "GetHeight", "height", transcript.height or 0)
end

local MESSAGES_PAGE_SIZE = 10

function ConversationPane.RenderTranscript(transcript, messages)
  local allMessages = messages or {}
  transcript.lines = {}

  for _, message in ipairs(allMessages) do
    table.insert(transcript.lines, formatMessage(message))
  end

  -- Determine visible slice (last N messages)
  local totalCount = #allMessages
  transcript._allMessages = allMessages
  transcript._visibleCount = transcript._visibleCount or MESSAGES_PAGE_SIZE
  if transcript._visibleCount > totalCount then
    transcript._visibleCount = totalCount
  end

  local startIndex = math.max(1, totalCount - transcript._visibleCount + 1)
  local visibleMessages = {}
  for i = startIndex, totalCount do
    table.insert(visibleMessages, allMessages[i])
  end

  if not transcript.factory then
    local visibleLines = {}
    for i = startIndex, totalCount do
      table.insert(visibleLines, transcript.lines[i])
    end
    if transcript.text then
      transcript.text:SetText(table.concat(visibleLines, "\n"))
    end
    updateTranscriptLayout(transcript, true)
    return transcript.lines
  end

  -- Keep legacy text content (for accessibility / backward compat) but hide renderer
  if transcript.text then
    transcript.text:SetText(table.concat(transcript.lines, "\n"))
    if transcript.text.Hide then transcript.text:Hide() end
  end

  local paneWidth = sizeValue(transcript.scrollFrame, "GetWidth", "width", 400)
  local totalHeight = ChatBubble.LayoutMessages(transcript.factory, transcript.content, visibleMessages, paneWidth)

  ScrollView.RefreshMetrics(transcript, totalHeight, true)

  -- Sync legacy text width with viewport for backward compat
  if transcript.text and transcript.text.SetWidth then
    transcript.text:SetWidth(sizeValue(transcript.scrollFrame, "GetWidth", "width", paneWidth))
  end

  transcript.point = pointValue(transcript.scrollFrame, transcript.point)
  transcript.width = sizeValue(transcript.scrollFrame, "GetWidth", "width", transcript.width or 0)
  transcript.height = sizeValue(transcript.scrollFrame, "GetHeight", "height", transcript.height or 0)

  return transcript.lines
end

function ConversationPane.HasMore(transcript)
  if not transcript._allMessages then return false end
  return (transcript._visibleCount or 0) < #transcript._allMessages
end

function ConversationPane.LoadMore(transcript)
  if not ConversationPane.HasMore(transcript) then return false end
  transcript._visibleCount = (transcript._visibleCount or MESSAGES_PAGE_SIZE) + MESSAGES_PAGE_SIZE
  ConversationPane.RenderTranscript(transcript, transcript._allMessages)
  return true
end

function ConversationPane.SetStatus(view, status)
  if view.statusBanner == nil then
    return nil
  end

  view.statusBanner:SetText(status and status.status or "")
  return view.statusBanner.text
end

local AVAILABILITY_DISPLAY = {
  CanWhisper      = { label = "Online",        color = "online" },
  CanWhisperGuild = { label = "Online",        color = "online" },
  Offline         = { label = "Offline",       color = "offline" },
  WrongFaction    = { label = "Wrong Faction", color = "offline" },
  Lockdown        = { label = "Unavailable",   color = "dnd" },
}

local function buildStatusLine(selectedContact, status)
  if not selectedContact then
    return "", nil
  end

  local parts = {}
  local dotColor = nil

  -- Availability status from the game API
  local statusKey = status and status.status or nil
  local avail = statusKey and AVAILABILITY_DISPLAY[statusKey] or nil
  if avail then
    table.insert(parts, avail.label)
    dotColor = avail.color
  end

  if selectedContact.realmName and selectedContact.realmName ~= "" then
    local name = selectedContact.name or selectedContact.displayName or ""
    if name ~= "" then
      table.insert(parts, name .. "-" .. selectedContact.realmName)
    else
      table.insert(parts, selectedContact.realmName)
    end
  elseif selectedContact.characterName and selectedContact.characterName ~= "" then
    local realm = selectedContact.realm or ""
    if realm ~= "" then
      table.insert(parts, selectedContact.characterName .. "-" .. realm)
    else
      table.insert(parts, selectedContact.characterName)
    end
  end

  if selectedContact.className and selectedContact.className ~= "" then
    table.insert(parts, selectedContact.className)
  end

  -- Show faction (inferred from race, or direct from BNet API)
  local factionName = selectedContact.factionName
  if factionName and factionName ~= "" then
    table.insert(parts, factionName)
  end

  return table.concat(parts, "  \xC2\xB7  "), dotColor
end

function ConversationPane.Refresh(view, selectedContact, conversation, status)
  -- Update new Telegram-style header elements
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
        -- Apply class color if available
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
    local statusText, dotColorKey = buildStatusLine(selectedContact, status)
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
        view.headerStatusDot:SetVertexColor(dc[1], dc[2], dc[3], dc[4] or 1)
        view.headerStatusDot:SetShown(true)
      else
        view.headerStatusDot:SetShown(false)
      end
    end

    -- Update faction icon
    if view.headerFactionIcon then
      local factionPath = hasContact and selectedContact.factionName and Theme.FactionIcon(selectedContact.factionName) or nil
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

  -- Reset visible count when conversation changes
  view.transcript._visibleCount = MESSAGES_PAGE_SIZE
  ConversationPane.RenderTranscript(view.transcript, conversation and conversation.messages or {})
  ConversationPane.SetStatus(view, status)
  return view
end

function ConversationPane.Create(factory, parent, selectedContact, conversation)
  local pane = factory.CreateFrame("Frame", nil, parent)
  local parentWidth = sizeValue(parent, "GetWidth", "width", 600)
  local parentHeight = sizeValue(parent, "GetHeight", "height", 420)
  pane:SetAllPoints(parent)

  local HEADER_HEIGHT = 56

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
  local iconSize = Theme.LAYOUT.HEADER_ICON_SIZE  -- 32
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
    headerStatus:SetText(buildStatusLine(selectedContact))
    headerStatus:Show()
  else
    headerStatus:SetText("")
    headerStatus:Hide()
  end

  ---------------------------------------------------------------------------
  -- Status dot (8x8) anchored just left of status text
  ---------------------------------------------------------------------------
  local statusDot = headerFrame:CreateTexture(nil, "ARTWORK")
  local dotSize = Theme.LAYOUT.HEADER_STATUS_DOT_SIZE  -- 8
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

  ---------------------------------------------------------------------------
  -- Legacy statusBanner (kept for SetStatus compatibility)
  ---------------------------------------------------------------------------
  local statusBanner = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusBanner:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
  statusBanner:SetText("")

  ---------------------------------------------------------------------------
  -- Transcript ScrollView (anchored below header)
  ---------------------------------------------------------------------------
  local transcriptHeight = parentHeight - HEADER_HEIGHT - TRANSCRIPT_BOTTOM_GAP
  local transcript = ScrollView.Create(factory, pane, {
    width = parentWidth - 32,
    height = transcriptHeight,
    point = { "TOPLEFT", headerFrame, "BOTTOMLEFT", 16, -8 },
    step = TRANSCRIPT_SCROLL_STEP,
  })
  transcript.factory = factory
  transcript.point = pointValue(transcript.scrollFrame, nil)
  transcript.width = sizeValue(transcript.scrollFrame, "GetWidth", "width", parentWidth - 32)
  transcript.height = sizeValue(transcript.scrollFrame, "GetHeight", "height", transcriptHeight)
  transcript.text = factory.CreateFrame("EditBox", nil, transcript.content)
  transcript.text:SetPoint("TOPLEFT", transcript.content, "TOPLEFT", 0, 0)
  if transcript.text.SetMultiLine then
    transcript.text:SetMultiLine(true)
  end
  if transcript.text.SetAutoFocus then
    transcript.text:SetAutoFocus(false)
  end
  if transcript.text.EnableMouse then
    transcript.text:EnableMouse(true)
  end
  if transcript.text.SetHyperlinksEnabled then
    transcript.text:SetHyperlinksEnabled(true)
  end
  if transcript.text.SetFontObject then
    transcript.text:SetFontObject(_G.GameFontHighlightSmall or "GameFontHighlightSmall")
  end
  if transcript.text.SetWidth then
    transcript.text:SetWidth(sizeValue(transcript.scrollFrame, "GetWidth", "width", parentWidth - 32))
  end
  if transcript.text.SetScript then
    transcript.text:SetScript("OnHyperlinkClick", function(self, link, text, button)
      if type(_G.SetItemRef) == "function" then
        _G.SetItemRef(link, text, button, self)
      end
    end)
    transcript.text:SetScript("OnEditFocusGained", function(self)
      if self.ClearFocus then
        self:ClearFocus()
      end
    end)
  end
  transcript.text:SetText("")
  transcript.lines = {}
  updateTranscriptLayout(transcript, false)

  -- Infinite scroll: load older messages when scrolling near the top
  local function checkLoadMoreMessages()
    local offset = ScrollView.GetOffset(transcript)
    if offset <= TRANSCRIPT_SCROLL_STEP and ConversationPane.HasMore(transcript) then
      -- Remember current content height to preserve scroll position
      local prevHeight = sizeValue(transcript.content, "GetHeight", "height", 0)
      ConversationPane.LoadMore(transcript)
      local newHeight = sizeValue(transcript.content, "GetHeight", "height", 0)
      -- Adjust scroll so the user stays at the same visual position
      local delta = newHeight - prevHeight
      if delta > 0 then
        ScrollView.SetVerticalScroll(transcript, offset + delta)
      end
    end
  end

  if transcript.scrollFrame and transcript.scrollFrame.SetScript then
    local originalOnWheel = transcript.scrollFrame:GetScript("OnMouseWheel")
    transcript.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
      if originalOnWheel then
        originalOnWheel(self, delta)
      end
      checkLoadMoreMessages()
    end)
  end

  if transcript.scrollBar and transcript.scrollBar.SetScript then
    local originalOnValue = transcript.scrollBar:GetScript("OnValueChanged")
    transcript.scrollBar:SetScript("OnValueChanged", function(self, value)
      if originalOnValue then
        originalOnValue(self, value)
      end
      checkLoadMoreMessages()
    end)
  end

  local view = {
    frame = pane,
    -- Legacy header stub so any callers using view.header:SetText() don't crash
    header = headerName,
    headerFrame = headerFrame,
    headerClassIcon = classIcon,
    headerName = headerName,
    headerFactionIcon = headerFactionIcon,
    headerStatus = headerStatus,
    headerStatusDot = statusDot,
    headerEmpty = headerEmpty,
    statusBanner = statusBanner,
    transcript = transcript,
  }

  ConversationPane.Refresh(view, selectedContact, conversation)
  return view
end

ns.ConversationPane = ConversationPane

return ConversationPane
