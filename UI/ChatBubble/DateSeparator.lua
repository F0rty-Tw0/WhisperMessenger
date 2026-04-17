local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor

local DateSeparator = {}

function DateSeparator.CreateDateSeparator(factory, parent, timestamp, paneWidth)
  local height = Theme.LAYOUT.DATE_SEPARATOR_HEIGHT
  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetSize(paneWidth, height)

  -- Reuse cached regions or create once
  local labelFS = frame._labelFS
  if not labelFS then
    labelFS = frame:CreateFontString(nil, "OVERLAY")
    frame._labelFS = labelFS

    local lineLeft = frame:CreateTexture(nil, "ARTWORK")
    lineLeft:SetHeight(Theme.LAYOUT.DIVIDER_THICKNESS)
    applyColorTexture(lineLeft, Theme.COLORS.divider)
    lineLeft:SetPoint("LEFT", frame, "LEFT", Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER, 0)
    lineLeft:SetPoint("RIGHT", labelFS, "LEFT", -8, 0)
    frame._lineLeft = lineLeft

    local lineRight = frame:CreateTexture(nil, "ARTWORK")
    lineRight:SetHeight(Theme.LAYOUT.DIVIDER_THICKNESS)
    applyColorTexture(lineRight, Theme.COLORS.divider)
    lineRight:SetPoint("LEFT", labelFS, "RIGHT", 8, 0)
    lineRight:SetPoint("RIGHT", frame, "RIGHT", -Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER, 0)
    frame._lineRight = lineRight
  else
    -- Re-show cached regions (hidden during pool release)
    if labelFS.Show then
      labelFS:Show()
    end
    if frame._lineLeft and frame._lineLeft.Show then
      frame._lineLeft:Show()
    end
    if frame._lineRight and frame._lineRight.Show then
      frame._lineRight:Show()
    end
  end

  setFontObject(labelFS, Theme.FONTS.date_separator)
  setTextColor(labelFS, Theme.COLORS.text_timestamp)

  local dateStr = ""
  if ns.TimeFormat and ns.TimeFormat.DateSeparator then
    dateStr = ns.TimeFormat.DateSeparator(timestamp) or ""
  end
  if labelFS.SetText then
    labelFS:SetText(dateStr)
  end
  labelFS:ClearAllPoints()
  labelFS:SetPoint("CENTER", frame, "CENTER", 0, 0)

  return { frame = frame, height = height }
end

ns.ChatBubbleDateSeparator = DateSeparator
return DateSeparator
