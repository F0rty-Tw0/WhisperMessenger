local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")

local BlizzardChrome = {}

-- Adds a localized "Close" tooltip to a template close button, keeping any
-- hover scripts the template already set.
function BlizzardChrome.AttachCloseTooltip(closeButton)
  if not (closeButton and closeButton.SetScript) then
    return
  end
  local previousOnEnter = closeButton.GetScript and closeButton:GetScript("OnEnter")
  local previousOnLeave = closeButton.GetScript and closeButton:GetScript("OnLeave")
  closeButton:SetScript("OnEnter", function(...)
    if previousOnEnter then
      previousOnEnter(...)
    end
    PickerStyles.ShowTooltipText(closeButton, Localization.Text("Close"))
  end)
  closeButton:SetScript("OnLeave", function(...)
    if previousOnLeave then
      previousOnLeave(...)
    end
    PickerStyles.HideTooltip()
  end)
end

-- The addon-owned frame every pane parents to, inside the active HUD
-- template's border and below its title bar.
function BlizzardChrome.CreateContentArea(factory, frame, layout)
  local insets = Hud.ContentInsets(layout)
  local contentArea = factory.CreateFrame("Frame", nil, frame)
  contentArea:SetPoint("TOPLEFT", frame, "TOPLEFT", insets.left, -insets.top)
  contentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -insets.right, insets.bottom)
  return contentArea
end

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

  BlizzardChrome.AttachCloseTooltip(closeButton)
  frame.contentArea = BlizzardChrome.CreateContentArea(factory, frame, theme.LAYOUT)

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
