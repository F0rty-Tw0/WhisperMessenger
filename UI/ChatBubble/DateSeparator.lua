local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

local Loader = ns.Loader or require("WhisperMessenger.Core.Loader")
local loadModule = Loader.LoadModule
local Theme = loadModule("WhisperMessenger.UI.Theme", "Theme")
local UIHelpers = loadModule("WhisperMessenger.UI.Helpers", "UIHelpers")
local applyColorTexture = UIHelpers.applyColorTexture
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor

local DateSeparator = {}

function DateSeparator.CreateDateSeparator(factory, parent, timestamp, paneWidth)
  local height = Theme.LAYOUT.DATE_SEPARATOR_HEIGHT
  local frame  = factory.CreateFrame("Frame", nil, parent)
  frame:SetSize(paneWidth, height)

  -- Date label
  local labelFS = frame:CreateFontString(nil, "OVERLAY")
  setFontObject(labelFS, Theme.FONTS.date_separator)
  setTextColor(labelFS, Theme.COLORS.text_timestamp)

  local dateStr = ""
  if ns.TimeFormat and ns.TimeFormat.DateSeparator then
    dateStr = ns.TimeFormat.DateSeparator(timestamp) or ""
  end
  if labelFS.SetText then
    labelFS:SetText(dateStr)
  end
  labelFS:SetPoint("CENTER", frame, "CENTER", 0, 0)

  -- Left line
  local lineLeft = frame:CreateTexture(nil, "ARTWORK")
  lineLeft:SetHeight(1)
  applyColorTexture(lineLeft, Theme.COLORS.divider)
  lineLeft:SetPoint("LEFT",  frame,  "LEFT",  16, 0)
  lineLeft:SetPoint("RIGHT", labelFS, "LEFT", -8, 0)

  -- Right line
  local lineRight = frame:CreateTexture(nil, "ARTWORK")
  lineRight:SetHeight(1)
  applyColorTexture(lineRight, Theme.COLORS.divider)
  lineRight:SetPoint("LEFT",  labelFS, "RIGHT",  8, 0)
  lineRight:SetPoint("RIGHT", frame,   "RIGHT", -16, 0)

  return { frame = frame, height = height }
end

ns.ChatBubbleDateSeparator = DateSeparator
return DateSeparator
