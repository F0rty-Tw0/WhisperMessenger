local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor

local SenderLabel = {}

local function defaultOpenPlayerMenu(message, anchor)
  local PM = ns.ChatBubblePlayerMenu
  if type(PM) ~= "table" or type(PM.Open) ~= "function" then
    return false
  end
  return PM.Open(message, anchor)
end

local function attachPlayerMenuHandler(frame, message, opener)
  if type(frame.EnableMouse) ~= "function" or type(frame.SetScript) ~= "function" then
    return
  end
  frame:EnableMouse(true)
  frame:SetScript("OnMouseUp", function(self, button)
    if button ~= "RightButton" then
      return
    end
    opener(message, self)
  end)
end

-- Pooled frames are reused across renders. Creating a fresh FontString every
-- render parents it to the recycled frame; WoW can't GC frame regions, so
-- they pile up indefinitely. Cache each FontString on the frame the first
-- time and reuse on subsequent renders.
local function ensureFontString(frame, cacheKey)
  local fs = frame[cacheKey]
  if not fs then
    fs = frame:CreateFontString(nil, "OVERLAY")
    frame[cacheKey] = fs
  end
  fs:ClearAllPoints()
  if fs.Show then
    fs:Show()
  end
  return fs
end

local function hideCached(frame, cacheKey)
  local fs = frame[cacheKey]
  if fs and fs.Hide then
    fs:Hide()
  end
end

function SenderLabel.CreateSenderLabel(factory, contentFrame, message, paneWidth, yOffset, options)
  options = options or {}
  local frame = factory.CreateFrame("Frame", nil, contentFrame)
  frame:SetSize(paneWidth, 16)
  frame:ClearAllPoints()

  local nameFS = ensureFontString(frame, "_wmSenderNameFS")
  setFontObject(nameFS, Theme.FONTS.message_time)
  setTextColor(nameFS, Theme.COLORS.text_secondary)

  local timeStr = ""
  if ns.TimeFormat and ns.TimeFormat.MessageTime then
    timeStr = ns.TimeFormat.MessageTime(message.sentAt) or ""
  end
  local timeFS = ensureFontString(frame, "_wmSenderTimeFS")
  setFontObject(timeFS, Theme.FONTS.message_time)
  setTextColor(timeFS, Theme.COLORS.text_timestamp)
  timeFS:SetText(timeStr)

  if message.direction == "out" then
    nameFS:SetText(Localization.Text("You"))

    -- Cross-character outgoing: append a gold "· <CharName>" suffix that
    -- mirrors the incoming "· via <Channel>" tag. Resolved at render time
    -- against the current player, so same-character messages stay plain.
    local attachedCharname = false
    if type(message.senderName) == "string" and message.senderName ~= "" then
      local currentPlayerName
      if type(_G.UnitName) == "function" then
        local ok, name = pcall(_G.UnitName, "player")
        if ok and type(name) == "string" and name ~= "" then
          currentPlayerName = name
        end
      end
      if currentPlayerName and currentPlayerName ~= message.senderName then
        local charnameFS = ensureFontString(frame, "_wmSenderCharnameFS")
        setFontObject(charnameFS, Theme.FONTS.message_time)
        charnameFS:SetTextColor(0.96, 0.78, 0.24, 1.0) -- match channel tag gold
        charnameFS:SetText("- " .. message.senderName)
        charnameFS:SetPoint("RIGHT", frame, "RIGHT", -Theme.LAYOUT.MESSAGE_EDGE_INSET, 0)
        nameFS:SetPoint("RIGHT", charnameFS, "LEFT", -4, 0)
        attachedCharname = true
      end
    end
    if not attachedCharname then
      hideCached(frame, "_wmSenderCharnameFS")
      nameFS:SetPoint("RIGHT", frame, "RIGHT", -Theme.LAYOUT.MESSAGE_EDGE_INSET, 0)
    end
    -- Outgoing labels never show the channel tag; hide it if this pooled
    -- frame previously rendered an incoming message with a channel.
    hideCached(frame, "_wmSenderTagFS")
    timeFS:SetPoint("RIGHT", nameFS, "LEFT", -Theme.LAYOUT.MESSAGE_TIMESTAMP_GAP, 0)
    frame:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", 0, -yOffset)
  else
    local displayName = message.playerName or message.senderDisplayName or ""
    nameFS:SetText(displayName)
    nameFS:SetPoint("LEFT", frame, "LEFT", Theme.LAYOUT.MESSAGE_EDGE_INSET, 0)

    -- Incoming labels never show the cross-char suffix; hide it if this
    -- pooled frame previously rendered an outgoing cross-char message.
    hideCached(frame, "_wmSenderCharnameFS")

    -- Channel tag as a separate colored FontString (e.g. "· via Trade")
    local channelAnchor = nameFS
    if message.channelLabel and message.channelLabel ~= "" then
      local tagFS = ensureFontString(frame, "_wmSenderTagFS")
      setFontObject(tagFS, Theme.FONTS.message_time)
      tagFS:SetTextColor(0.96, 0.78, 0.24, 1.0) -- hardcoded gold
      tagFS:SetText("- " .. Localization.Text("via ") .. Localization.Text(message.channelLabel))
      tagFS:SetPoint("LEFT", nameFS, "RIGHT", 4, 0)
      channelAnchor = tagFS
    else
      hideCached(frame, "_wmSenderTagFS")
    end

    timeFS:SetPoint("LEFT", channelAnchor, "RIGHT", Theme.LAYOUT.MESSAGE_TIMESTAMP_GAP, 0)
    frame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
  end

  if message.direction == "in" then
    attachPlayerMenuHandler(frame, message, options.openPlayerMenu or defaultOpenPlayerMenu)
  end

  return { frame = frame, height = 18 }
end

ns.ChatBubbleSenderLabel = SenderLabel
return SenderLabel
