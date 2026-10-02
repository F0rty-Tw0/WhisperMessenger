local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Divider = ns.SettingsControlsDivider or require("WhisperMessenger.UI.Shared.SettingsControls.Divider")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")

-- Settings panel header (title + hint). The title renders as a small
-- "--- Title ---" section label: secondary colour, centered, with a
-- pixel hairline on each side fading out away from the text. The text is
-- shown as localized (no forced uppercase: string.upper breaks non-ASCII).
local Header = {}

local LINE_GAP = 8
-- Title line height plus spacing above the hint.
local TITLE_BLOCK = 18
-- Native WoW HUD: the game's section-title font, then one divider line.
Header.NATIVE_TITLE_FONT = "GameFontNormalLarge"
local NATIVE_LINE_GAP = 4
local NATIVE_HINT_GAP = 8

local function createHint(frame, opts, bandWidth)
  local hint = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  hint:SetText(opts.hint or "")
  if hint.SetWordWrap then
    hint:SetWordWrap(true)
  end
  if hint.SetJustifyH then
    hint:SetJustifyH("LEFT")
  end
  if hint.SetWidth then
    hint:SetWidth(bandWidth)
  end
  return hint
end

-- Every header style's refreshLayout: the hint takes the new width, then
-- setBandWidth stores it and repaints.
local function layoutRefresher(hint, setBandWidth)
  return function(width)
    if hint.SetWidth and type(width) == "number" and width > 0 then
      hint:SetWidth(width)
      setBandWidth(width)
    end
  end
end

-- Left-aligned title in the preset's title colour, a single divider under
-- it, then the hint. leftLine/rightLine are the divider's two halves.
local function createNative(frame, opts)
  local PADDING = Theme.CONTENT_PADDING
  local bandWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH

  local title = frame:CreateFontString(nil, "OVERLAY")
  UIHelpers.setFontObject(title, Header.NATIVE_TITLE_FONT)
  title:SetText(opts.title or "")
  if title.SetJustifyH then
    title:SetJustifyH("LEFT")
  end
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)

  local divider = Divider.Create(frame)
  divider.left:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -NATIVE_LINE_GAP)

  local hint = createHint(frame, opts, bandWidth)
  hint:SetPoint("TOPLEFT", divider.left, "BOTTOMLEFT", 0, -NATIVE_HINT_GAP)

  local function applyTheme(activeTheme)
    activeTheme = activeTheme or Theme
    UIHelpers.setTextColor(title, activeTheme.COLORS.text_title or activeTheme.COLORS.text_primary)
    UIHelpers.setTextColor(hint, activeTheme.COLORS.text_secondary)
    divider.setWidth(bandWidth)
    divider.applyTheme(activeTheme)
  end

  applyTheme(Theme)

  return {
    title = title,
    hint = hint,
    leftLine = divider.left,
    rightLine = divider.right,
    refreshTheme = applyTheme,
    refreshLayout = layoutRefresher(hint, function(width)
      bandWidth = width
      applyTheme(Theme)
    end),
  }
end

function Header.Create(frame, opts)
  opts = opts or {}
  if Hud.IsOn() then
    return createNative(frame, opts)
  end
  local PADDING = Theme.CONTENT_PADDING
  local bandWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH

  local title = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_name)
  title:SetText(opts.title or "")

  local hint = createHint(frame, opts, bandWidth)

  local leftLine = Divider.createLine(frame)
  leftLine:SetPoint("RIGHT", title, "LEFT", -LINE_GAP, 0)
  local rightLine = Divider.createLine(frame)
  rightLine:SetPoint("LEFT", title, "RIGHT", LINE_GAP, 0)

  local function applyTheme(activeTheme)
    activeTheme = activeTheme or Theme
    UIHelpers.setTextColor(hint, activeTheme.COLORS.text_secondary)
    UIHelpers.setFontObject(title, activeTheme.FONTS.system_text)
    UIHelpers.setTextColor(title, activeTheme.COLORS.text_secondary)
    title:ClearAllPoints()
    title:SetPoint("TOP", frame, "TOPLEFT", PADDING + bandWidth / 2, -PADDING)
    hint:ClearAllPoints()
    hint:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -(PADDING + TITLE_BLOCK))
    local lineWidth = math.max(0, (bandWidth - (title:GetStringWidth() or 0)) / 2 - LINE_GAP)
    leftLine:SetWidth(lineWidth)
    rightLine:SetWidth(lineWidth)
    Divider.paint(leftLine, rightLine, activeTheme)
    leftLine:Show()
    rightLine:Show()
  end

  applyTheme(Theme)

  return {
    title = title,
    hint = hint,
    leftLine = leftLine,
    rightLine = rightLine,
    refreshTheme = applyTheme,
    refreshLayout = layoutRefresher(hint, function(width)
      bandWidth = width
      applyTheme(Theme)
    end),
  }
end

ns.SettingsControlsHeader = Header
return Header
