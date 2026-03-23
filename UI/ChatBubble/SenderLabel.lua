local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor

local SenderLabel = {}

function SenderLabel.CreateSenderLabel(factory, contentFrame, message, paneWidth, yOffset)
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
    nameFS:SetPoint("RIGHT", frame, "RIGHT", -48, 0)
    timeFS:SetPoint("RIGHT", nameFS, "LEFT", -6, 0)
    frame:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", 0, -yOffset)
  else
    local displayName = message.playerName or message.senderDisplayName or ""
    nameFS:SetText(displayName)
    nameFS:SetPoint("LEFT", frame, "LEFT", 48, 0)
    timeFS:SetPoint("LEFT", nameFS, "RIGHT", 6, 0)
    frame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
  end

  return { frame = frame, height = 18 }
end

ns.ChatBubbleSenderLabel = SenderLabel
return SenderLabel
