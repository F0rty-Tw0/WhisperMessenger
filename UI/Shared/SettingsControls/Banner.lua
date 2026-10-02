local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local NativeArt = ns.UIHelpersNativeArt or require("WhisperMessenger.UI.Helpers.NativeArt")

-- Retail Native WoW HUD: the ornate section banner from the character
-- window's stats pane, with a text label centred on it. Settings page titles
-- and sub-section labels sit on it. The banner stretches across the control
-- band; the text keeps the preset's title colour.
local Banner = {}

Banner.ATLAS = "UI-Character-Info-Title"
-- Page banner height when the client can't report the atlas's own height.
Banner.FALLBACK_HEIGHT = 40
Banner.SECTION_HEIGHT = 26
Banner.SECTION_FONT = "GameFontNormal"

-- The atlas's natural height, so a page banner keeps its art's proportions
-- vertically while stretching horizontally.
function Banner.PageHeight()
  local info = NativeArt.AtlasInfo(Banner.ATLAS)
  if info and type(info.height) == "number" and info.height > 0 then
    return info.height
  end
  return Banner.FALLBACK_HEIGHT
end

-- Returns { texture, label, setWidth, applyTheme }, or nil when the client's
-- textures can't draw atlases (the caller falls back to its plain look).
-- Anchor the banner by `texture`.
function Banner.Create(frame, height, fontObject)
  local texture = frame:CreateTexture(nil, "BACKGROUND")
  if not NativeArt.SetAtlas(texture, Banner.ATLAS, false) then
    texture:Hide()
    return nil
  end
  texture:SetHeight(height)
  texture:SetWidth(Theme.LAYOUT.SETTINGS_CONTROL_WIDTH)

  local label = frame:CreateFontString(nil, "OVERLAY")
  UIHelpers.setFontObject(label, fontObject)
  if label.SetJustifyH then
    label:SetJustifyH("CENTER")
  end
  label:SetPoint("CENTER", texture, "CENTER", 0, 0)

  return {
    texture = texture,
    label = label,
    setWidth = function(width)
      texture:SetWidth(width)
    end,
    applyTheme = function(activeTheme)
      activeTheme = activeTheme or Theme
      UIHelpers.setTextColor(label, activeTheme.COLORS.text_title or activeTheme.COLORS.text_primary)
    end,
  }
end

ns.SettingsControlsBanner = Banner
return Banner
