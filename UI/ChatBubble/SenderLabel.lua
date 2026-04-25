local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
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

function SenderLabel.CreateSenderLabel(factory, contentFrame, message, paneWidth, yOffset, options)
  options = options or {}
  local frame = factory.CreateFrame("Frame", nil, contentFrame)
  frame:SetSize(paneWidth, 16)
  frame:ClearAllPoints()

  local nameFS = frame:CreateFontString(nil, "OVERLAY")
  setFontObject(nameFS, Theme.FONTS.message_time)
  setTextColor(nameFS, Theme.COLORS.text_secondary)

  local timeStr = ""
  if ns.TimeFormat and ns.TimeFormat.MessageTime then
    timeStr = ns.TimeFormat.MessageTime(message.sentAt) or ""
  end
  local timeFS = frame:CreateFontString(nil, "OVERLAY")
  setFontObject(timeFS, Theme.FONTS.message_time)
  setTextColor(timeFS, Theme.COLORS.text_timestamp)
  timeFS:SetText(timeStr)

  if message.direction == "out" then
    nameFS:SetText("You")

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
        local charnameFS = frame:CreateFontString(nil, "OVERLAY")
        setFontObject(charnameFS, Theme.FONTS.message_time)
        charnameFS:SetTextColor(0.96, 0.78, 0.24, 1.0) -- match channel tag gold
        charnameFS:SetText("\194\183 " .. message.senderName)
        charnameFS:SetPoint("RIGHT", frame, "RIGHT", -Theme.LAYOUT.MESSAGE_EDGE_INSET, 0)
        nameFS:SetPoint("RIGHT", charnameFS, "LEFT", -4, 0)
        attachedCharname = true
      end
    end
    if not attachedCharname then
      nameFS:SetPoint("RIGHT", frame, "RIGHT", -Theme.LAYOUT.MESSAGE_EDGE_INSET, 0)
    end
    timeFS:SetPoint("RIGHT", nameFS, "LEFT", -Theme.LAYOUT.MESSAGE_TIMESTAMP_GAP, 0)
    frame:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", 0, -yOffset)
  else
    local displayName = message.playerName or message.senderDisplayName or ""
    nameFS:SetText(displayName)
    nameFS:SetPoint("LEFT", frame, "LEFT", Theme.LAYOUT.MESSAGE_EDGE_INSET, 0)

    -- Channel tag as a separate colored FontString (e.g. "· via Trade")
    local channelAnchor = nameFS
    if message.channelLabel and message.channelLabel ~= "" then
      local tagFS = frame:CreateFontString(nil, "OVERLAY")
      setFontObject(tagFS, Theme.FONTS.message_time)
      tagFS:SetTextColor(0.96, 0.78, 0.24, 1.0) -- hardcoded gold
      tagFS:SetText("\194\183 via " .. message.channelLabel)
      tagFS:SetPoint("LEFT", nameFS, "RIGHT", 4, 0)
      channelAnchor = tagFS
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
