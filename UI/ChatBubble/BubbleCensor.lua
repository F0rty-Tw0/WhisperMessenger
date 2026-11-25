local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor

-- A message the game's profanity filter censored: a "(click to reveal)"
-- hint under the text, and a left click that swaps in the real words.
local BubbleCensor = {}

local CENSORED_LABEL_HEIGHT = 12

-- Uncensors the bubble's message and asks the transcript to re-render.
-- No-op for a message that is not censored.
function BubbleCensor.Reveal(frame)
  local message = frame._wmMessage
  if message == nil or message.isCensored ~= true then
    return
  end
  local chatApi = _G.C_ChatInfo
  if chatApi and message.lineID then
    if type(chatApi.UncensorChatLine) == "function" then
      pcall(chatApi.UncensorChatLine, message.lineID)
    end
    if type(chatApi.GetChatLineText) == "function" then
      local ok, uncensoredText = pcall(chatApi.GetChatLineText, message.lineID)
      if ok and type(uncensoredText) == "string" and uncensoredText ~= "" then
        message.text = uncensoredText
      end
    end
  end
  message.isCensored = nil
  if type(frame._wmOnRevealCensored) == "function" then
    frame._wmOnRevealCensored()
  end
end

-- Shows the hint under textFS for a censored message, hides it otherwise.
-- Returns the extra bubble height the hint takes (0 when hidden).
function BubbleCensor.ApplyLabel(frame, textFS, message)
  local censoredLabel = frame._censoredLabel
  if message.isCensored ~= true then
    if censoredLabel and censoredLabel.Hide then
      censoredLabel:Hide()
    end
    return 0
  end
  if not censoredLabel then
    censoredLabel = frame:CreateFontString(nil, "OVERLAY")
    if censoredLabel.SetWordWrap then
      censoredLabel:SetWordWrap(false)
    end
    frame._censoredLabel = censoredLabel
  end
  setFontObject(censoredLabel, Theme.FONTS.system_text)
  setTextColor(censoredLabel, Theme.COLORS.text_system)
  censoredLabel:SetText("(click to reveal)")
  censoredLabel:ClearAllPoints()
  censoredLabel:SetPoint("TOPLEFT", textFS, "BOTTOMLEFT", 0, -2)
  if censoredLabel.SetAlpha then
    censoredLabel:SetAlpha(0.7)
  end
  if censoredLabel.Show then
    censoredLabel:Show()
  end
  return CENSORED_LABEL_HEIGHT
end

ns.ChatBubbleBubbleCensor = BubbleCensor
return BubbleCensor
