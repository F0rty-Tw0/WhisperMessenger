local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local IconButtonStyle = ns.MessengerWindowChromeBuilderIconButtonStyle or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.IconButtonStyle")
local applyVertexColor = UIHelpers.applyVertexColor

-- Title-bar button for another addon's panel: the caller's icon and title
-- (no Localization: the text is theirs) and a count badge in its corner.
local PanelButton = {}

local BADGE_MAX = 99

local function badgeText(n)
  -- n ~= n: NaN.
  if type(n) ~= "number" or n ~= n or n < 1 then
    return nil
  end
  if n > BADGE_MAX then
    return BADGE_MAX .. "+"
  end
  return tostring(math.floor(n))
end

-- spec: { title, icon } (icon: texture path or file id). The caller sets
-- OnClick. Returns { button, icon, badge, setBadge(n), applyTheme }.
function PanelButton.Create(factory, frame, theme, spec)
  theme = theme or Theme

  local button = factory.CreateFrame("Button", nil, frame)
  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(button)
  IconButtonStyle.Attach(button, bg)
  local icon = button:CreateTexture(nil, "ARTWORK")
  IconButtonStyle.SetGlyph(button, icon, spec.icon)
  icon:SetSize(theme.LAYOUT.CHROME_BUTTON_ICON_SIZE, theme.LAYOUT.CHROME_BUTTON_ICON_SIZE)
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)

  local badge = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  badge:SetPoint("TOPRIGHT", button, "TOPRIGHT", 2, 2)
  badge:Hide()

  local function applyVisuals(hovered)
    applyVertexColor(icon, IconButtonStyle.Paint(button, hovered, theme.COLORS))
  end

  local function isHovered()
    return button.IsMouseOver and button:IsMouseOver()
  end

  if button.SetScript then
    button:SetScript("OnEnter", function()
      applyVisuals(true)
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(button, "ANCHOR_TOP")
        _G.GameTooltip:SetText(spec.title)
        _G.GameTooltip:Show()
      end
    end)
    button:SetScript("OnLeave", function()
      applyVisuals(false)
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)
  end
  button:EnableMouse(true)
  applyVisuals(false)

  local function setBadge(n)
    local text = badgeText(n)
    if text == nil then
      badge:Hide()
      return
    end
    badge:SetText(text)
    badge:Show()
  end

  return {
    button = button,
    icon = icon,
    badge = badge,
    setBadge = setBadge,
    applyTheme = function(nextTheme)
      theme = nextTheme or Theme
      applyVisuals(isHovered())
    end,
  }
end

ns.MessengerWindowChromeBuilderPanelButton = PanelButton
return PanelButton
