local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture

local BlizzardChrome = {}

-- Builds the Blizzard-template chrome branch. The outer frame is already
-- created with BasicFrameTemplateWithInset by ChromeBuilder.Build and passed
-- in as `frame`. This module supplies the title text, an extra title strip
-- (doubled top bar height) painted with bg_header, and repositions the
-- template's Inset to clear that extra strip.
function BlizzardChrome.Build(_factory, frame, options, theme)
  options = options or {}
  theme = theme or Theme

  local titleText = options.title or theme.TITLE
  if frame.SetTitle then
    frame:SetTitle(titleText)
  elseif frame.TitleText and frame.TitleText.SetText then
    frame.TitleText:SetText(titleText)
  end
  local background = frame.Bg
  local title = frame.TitleText
  local closeButton = frame.CloseButton

  -- Double the apparent top bar height: fill the space below the
  -- template's title strip with bg_header, and shift the Inset down
  -- by the same amount so content starts below the extended bar.
  local EXTRA_TITLE_HEIGHT = 24
  local topBarExtension = frame:CreateTexture(nil, "ARTWORK")
  topBarExtension:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -theme.LAYOUT.TOP_BAR_HEIGHT)
  -- -6 right matches the Inset's own BOTTOMRIGHT inset so the top status
  -- bar extension and the content area share the same right edge (2px
  -- more padding than the default 4px, giving the corner some breathing
  -- room away from the resize grip).
  topBarExtension:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -theme.LAYOUT.TOP_BAR_HEIGHT)
  topBarExtension:SetHeight(EXTRA_TITLE_HEIGHT)
  applyColorTexture(topBarExtension, theme.COLORS.bg_header)

  if frame.Inset and frame.Inset.ClearAllPoints and frame.Inset.SetPoint then
    frame.Inset:ClearAllPoints()
    frame.Inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -(theme.LAYOUT.TOP_BAR_HEIGHT + EXTRA_TITLE_HEIGHT))
    -- +8px of chrome visible at the bottom (Inset bottom raised).
    frame.Inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 34)
  end

  local function applyChromePaint(activeTheme)
    activeTheme = activeTheme or theme
    if topBarExtension then
      applyColorTexture(topBarExtension, activeTheme.COLORS.bg_header)
    end
  end

  return {
    background = background,
    title = title,
    closeButton = closeButton,
    applyChromePaint = applyChromePaint,
    topBarExtension = topBarExtension,
  }
end

ns.MessengerWindowChromeBuilderBlizzard = BlizzardChrome

return BlizzardChrome
