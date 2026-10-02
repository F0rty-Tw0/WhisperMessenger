local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local BlizzardChrome = ns.MessengerWindowChromeBuilderBlizzard or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.BlizzardChrome")

local RetailChrome = {}

-- Only the template's child keys are certain on the live client; its mixin
-- helpers are used when present and skipped otherwise.
local function setTitle(frame, text)
  if type(frame.SetTitle) == "function" then
    frame:SetTitle(text)
    return
  end
  local titleText = frame.TitleContainer and frame.TitleContainer.TitleText
  if titleText and titleText.SetText then
    titleText:SetText(text)
  end
end

local function setPortrait(frame, texturePath)
  if type(frame.SetPortraitToAsset) == "function" then
    frame:SetPortraitToAsset(texturePath)
    return
  end
  local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
  if portrait and portrait.SetTexture then
    portrait:SetTexture(texturePath)
  end
end

local function hideButtonBar(frame)
  local hide = _G.ButtonFrameTemplate_HideButtonBar
  if type(hide) == "function" then
    -- Unprobed Blizzard helper: if it throws, the window must still build.
    pcall(hide, frame)
  end
end

local function pin(inset, pane)
  if not (inset and pane) then
    return
  end
  inset:ClearAllPoints()
  inset:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
  inset:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
end

-- Builds the Retail-template chrome branch. ChromeBuilder.Build creates the
-- outer frame with ButtonFrameTemplate (round portrait, modern title bar)
-- and passes it in as `frame`. Panes still parent to the addon-owned
-- `frame.contentArea`; the template Inset (conversation side) and a second
-- InsetFrameTemplate (contacts side) only paint the panel backgrounds and
-- are pinned to the panes by AnchorInsets.
function RetailChrome.Build(factory, frame, options, theme)
  options = options or {}
  theme = theme or Theme

  setTitle(frame, options.title or theme.MODERN_TITLE)
  setPortrait(frame, theme.TEXTURES.addon_icon)
  hideButtonBar(frame)
  BlizzardChrome.AttachCloseTooltip(frame.CloseButton)

  frame.contentArea = BlizzardChrome.CreateContentArea(factory, frame, theme.LAYOUT)
  frame.conversationInset = frame.Inset
  frame.contactsInset = UIHelpers.createTemplatedFrame(factory, "Frame", nil, frame, "InsetFrameTemplate")

  -- The template paints all of its own chrome.
  local function applyChromePaint(_activeTheme) end

  return {
    background = frame.Bg,
    title = frame.TitleContainer and frame.TitleContainer.TitleText,
    closeButton = frame.CloseButton,
    applyChromePaint = applyChromePaint,
  }
end

-- Pins each panel inset to its pane, so the insets follow the
-- contacts/conversation split through anchors on every resize and drag.
function RetailChrome.AnchorInsets(frame, contactsPane, contentPane)
  pin(frame.contactsInset, contactsPane)
  pin(frame.conversationInset, contentPane)
end

ns.MessengerWindowChromeBuilderRetail = RetailChrome

return RetailChrome
