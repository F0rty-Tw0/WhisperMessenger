local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

local BlizzardChrome = {}

-- Builds the Blizzard-template chrome branch. The outer frame is already
-- created with BasicFrameTemplateWithInset by ChromeBuilder.Build and passed
-- in as `frame`. This module supplies the title text and `frame.contentArea`,
-- an addon-owned frame inside the template border that all panes use as
-- their parent (the live template exposes no Inset frame to anchor to).
function BlizzardChrome.Build(factory, frame, options, theme)
  options = options or {}
  theme = theme or Theme

  local titleText = options.title or theme.MODERN_TITLE
  if frame.SetTitle then
    frame:SetTitle(titleText)
  elseif frame.TitleText and frame.TitleText.SetText then
    frame.TitleText:SetText(titleText)
  end
  local background = frame.Bg
  local title = frame.TitleText
  local closeButton = frame.CloseButton

  if closeButton and closeButton.SetScript then
    local previousOnEnter = closeButton.GetScript and closeButton:GetScript("OnEnter")
    local previousOnLeave = closeButton.GetScript and closeButton:GetScript("OnLeave")
    closeButton:SetScript("OnEnter", function(...)
      if previousOnEnter then
        previousOnEnter(...)
      end
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(closeButton, "ANCHOR_TOP")
        _G.GameTooltip:SetText(Localization.Text("Close"))
        _G.GameTooltip:Show()
      end
    end)
    closeButton:SetScript("OnLeave", function(...)
      if previousOnLeave then
        previousOnLeave(...)
      end
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)
  end

  local L = theme.LAYOUT
  local pad = L.HUD_CONTENT_INSET
  local contentArea = factory.CreateFrame("Frame", nil, frame)
  contentArea:SetPoint("TOPLEFT", frame, "TOPLEFT", L.HUD_INSET_LEFT + pad, -(L.TOP_BAR_HEIGHT + L.HUD_CONTENT_TOP_INSET))
  contentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(L.HUD_INSET_RIGHT + pad), L.HUD_INSET_BOTTOM + pad)
  frame.contentArea = contentArea

  -- The template paints all of its own chrome.
  local function applyChromePaint(_activeTheme) end

  return {
    background = background,
    title = title,
    closeButton = closeButton,
    applyChromePaint = applyChromePaint,
  }
end

ns.MessengerWindowChromeBuilderBlizzard = BlizzardChrome

return BlizzardChrome
