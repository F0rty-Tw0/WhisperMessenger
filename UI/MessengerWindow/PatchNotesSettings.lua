local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local setTextColor = UIHelpers.setTextColor

local PatchNotesSettings = {}

local PADDING = Theme.CONTENT_PADDING
local BODY_TOP_GAP = -24
local MIN_BODY_WIDTH = 160
local BULLET_PREFIX = "• "
local LINE_SEPARATOR = "\n\n"

local function text(key)
  return Localization.Text(key)
end

-- The notes themselves are baked from the English CHANGELOG, so the
-- localized hint carries a localized "(English only)" disclaimer.
local function hintText()
  return text("See what changed in the latest update.") .. " (" .. text("English only") .. ")"
end

local function buildTitle(config)
  local title = text("What's New")
  if type(config.version) == "string" and config.version ~= "" then
    title = title .. " " .. config.version
  end
  if type(config.date) == "string" and config.date ~= "" then
    title = title .. " · " .. config.date
  end
  return title
end

local function buildBody(config)
  local bullets = {}
  for _, line in ipairs(config.lines or {}) do
    bullets[#bullets + 1] = BULLET_PREFIX .. line
  end
  return table.concat(bullets, LINE_SEPARATOR)
end

function PatchNotesSettings.Create(factory, parent, config, _options)
  config = config or {}

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local header = SettingsControls.CreateHeader(frame, {
    title = buildTitle(config),
    hint = hintText(),
  })

  -- message_text follows the Options font size, so the notes read at the
  -- same size as the chat thread.
  local bodyText = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.message_text)
  bodyText:SetPoint("TOPLEFT", header.hint, "BOTTOMLEFT", 0, BODY_TOP_GAP)
  bodyText:SetText(buildBody(config))
  bodyText:SetJustifyH("LEFT")
  if bodyText.SetJustifyV then
    bodyText:SetJustifyV("TOP")
  end
  if bodyText.SetWordWrap then
    bodyText:SetWordWrap(true)
  end

  -- A wrapped FontString's bottom tracks its rendered height in WoW, so
  -- anchoring the marker to the body keeps the scroll measurement correct.
  local bottomSpacer = factory.CreateFrame("Frame", nil, frame)
  bottomSpacer:SetSize(1, PADDING)
  bottomSpacer:SetPoint("TOPLEFT", bodyText, "BOTTOMLEFT", 0, 0)
  frame._wmBottomMarker = bottomSpacer

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    header.refreshTheme(activeTheme)
    setTextColor(bodyText, activeTheme.COLORS.text_primary)
  end

  refreshTheme(Theme)

  local function setLanguage()
    header.title:SetText(buildTitle(config))
    header.hint:SetText(hintText())
  end

  -- Release notes are prose, so the body uses the full pane width rather
  -- than the SETTINGS_CONTROL_WIDTH cap the control-based pages apply.
  local function refreshLayout(width)
    if type(width) ~= "number" or width <= 0 then
      return
    end
    local effective = math.max(MIN_BODY_WIDTH, math.floor(width))
    header.refreshLayout(effective)
    if bodyText.SetWidth then
      bodyText:SetWidth(effective)
    end
  end

  return {
    frame = frame,
    header = header,
    bodyText = bodyText,
    refreshTheme = refreshTheme,
    refreshLayout = refreshLayout,
    setLanguage = setLanguage,
  }
end

ns.PatchNotesSettings = PatchNotesSettings
return PatchNotesSettings
