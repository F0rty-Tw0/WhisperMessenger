local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local Banner = ns.SettingsControlsBanner or require("WhisperMessenger.UI.Shared.SettingsControls.Banner")

-- A sub-section label inside a settings page ("Privacy", "Time Display").
-- Returns { label, region, refreshTheme, refreshLayout }: set the text on
-- `label`, anchor `region` and hang the next control below `region`.
-- Modern and Classic HUD: a small label in the secondary colour. Retail HUD:
-- the label centred on a short character-window section banner.
local SectionLabel = {}

local function createRetail(frame, text)
  local banner = Banner.Create(frame, Banner.SECTION_HEIGHT, Banner.SECTION_FONT)
  if not banner then
    return nil
  end
  banner.label:SetText(text or "")
  banner.applyTheme(Theme)
  return {
    label = banner.label,
    region = banner.texture,
    refreshTheme = banner.applyTheme,
    refreshLayout = function(width)
      if type(width) == "number" and width > 0 then
        banner.setWidth(width)
      end
    end,
  }
end

function SectionLabel.Create(frame, text)
  local retail = Hud.IsRetail() and createRetail(frame, text)
  if retail then
    return retail
  end

  local label = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  label:SetText(text or "")

  local function refreshTheme(activeTheme)
    UIHelpers.setTextColor(label, (activeTheme or Theme).COLORS.text_secondary)
  end
  refreshTheme(Theme)

  return {
    label = label,
    region = label,
    refreshTheme = refreshTheme,
    refreshLayout = function(_width) end,
  }
end

ns.SettingsControlsSectionLabel = SectionLabel
return SectionLabel
