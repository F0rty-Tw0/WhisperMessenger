local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

-- Settings panel header (title + hint). The title renders as a small
-- "--- Title ---" section label: secondary colour, centered, with a
-- pixel hairline on each side fading out away from the text. The text is
-- shown as localized (no forced uppercase: string.upper breaks non-ASCII).
local Header = {}

local LINE_GAP = 8
-- Title line height plus spacing above the hint.
local TITLE_BLOCK = 18

function Header.Create(frame, opts)
  opts = opts or {}
  local PADDING = Theme.CONTENT_PADDING
  local bandWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH

  local title = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_name)
  title:SetText(opts.title or "")

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

  local leftLine = frame:CreateTexture(nil, "ARTWORK")
  leftLine:SetPoint("RIGHT", title, "LEFT", -LINE_GAP, 0)
  local rightLine = frame:CreateTexture(nil, "ARTWORK")
  rightLine:SetPoint("LEFT", title, "RIGHT", LINE_GAP, 0)
  for _, line in ipairs({ leftLine, rightLine }) do
    line:SetHeight(UIHelpers.hairlineThickness(frame, 1))
    UIHelpers.snapToPixelGrid(line)
  end

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
    local lineColor = activeTheme.COLORS.contacts_border_right or activeTheme.COLORS.divider
    leftLine:SetWidth(lineWidth)
    rightLine:SetWidth(lineWidth)
    UIHelpers.applyHorizontalFadeLeft(leftLine, lineColor)
    UIHelpers.applyHorizontalFade(rightLine, lineColor)
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
    refreshLayout = function(width)
      if hint.SetWidth and type(width) == "number" and width > 0 then
        hint:SetWidth(width)
        bandWidth = width
        applyTheme(Theme)
      end
    end,
  }
end

ns.SettingsControlsHeader = Header
return Header
