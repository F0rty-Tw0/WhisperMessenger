local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- "How filters work" section at the top of the Filters page: what the ignore
-- list and keyword rules hide, and the rule syntax with one example each.
-- The lines wrap to the page width, so the page grows with them.
local HelpSection = {}

local TITLE = "How filters work"
local LINES = {
  "Ignored players: their whispers, group and channel messages are hidden in WhisperMessenger, and their say, yell, emote and channel messages in the game's chat too.",
  "Keyword rules: hide matching group and channel messages in WhisperMessenger, and matching channel messages in the game's chat. Never whispers or your own messages.",
  "Ready-made rules only filter channels such as Trade, never group chats.",
  "WhisperMessenger never hides anything from the game's chat in Mythic+, boss fights or PvP.",
  "gold + cheap: both words must appear, in any order.",
  "wts/wtb: either word is enough.",
  '"lf": whole word only, so "half" doesn\'t match.',
}
local GAP = 6

local function text(key)
  return Localization.Text(key)
end

-- Returns the section with `bottom` (the frame the next control anchors below).
function HelpSection.Create(frame, anchor)
  local width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
  local titleSection = SettingsControls.CreateSectionLabel(frame, text(TITLE))
  titleSection.region:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  local lines = {}
  local previous = titleSection.region
  for index, key in ipairs(LINES) do
    local line = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
    line:SetText(text(key))
    line:SetJustifyH("LEFT")
    line:SetWordWrap(true)
    line:SetWidth(width)
    line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -GAP)
    lines[index] = line
    previous = line
  end

  local section = { bottom = previous }

  function section.refreshTheme()
    titleSection.refreshTheme(Theme)
    for _, line in ipairs(lines) do
      UIHelpers.setTextColor(line, Theme.COLORS.text_secondary)
    end
  end

  function section.refreshLayout(nextWidth)
    titleSection.refreshLayout(nextWidth)
    for _, line in ipairs(lines) do
      line:SetWidth(nextWidth)
    end
  end

  function section.setLanguage()
    titleSection.label:SetText(text(TITLE))
    for index, key in ipairs(LINES) do
      lines[index]:SetText(text(key))
    end
  end

  section.refreshTheme()
  return section
end

ns.FiltersSettingsHelpSection = HelpSection
return HelpSection
