local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local PulseGlow = ns.ToggleIconPulseGlow or require("WhisperMessenger.UI.ToggleIcon.PulseGlow")
local applyColorTexture = UIHelpers.applyColorTexture
local setTextColor = UIHelpers.setTextColor

local IDLE_BG_ALPHA = 0.35
local HOVER_BG_ALPHA = 0.75

local PatchNotesButton = {}

-- Creates the "?" title-bar button that opens the What's New dialog. It sits
-- immediately right of the New Whisper button and pulses while the shipped
-- patch-notes version has not been seen yet (glow is driven by setGlowing).
function PatchNotesButton.Create(factory, frame, anchorButton, theme)
  theme = theme or Theme

  local button = factory.CreateFrame("Button", nil, frame)
  button:SetSize(theme.LAYOUT.CHROME_BUTTON_SIZE, theme.LAYOUT.CHROME_BUTTON_SIZE)
  button:SetPoint("LEFT", anchorButton, "RIGHT", 2, 0)

  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(button)

  local label = button:CreateFontString(nil, "OVERLAY", theme.FONTS.contact_name)
  label:SetPoint("CENTER", button, "CENTER", 0, 0)
  label:SetText("?")

  local function applyVisuals(hovered)
    local colors = theme.COLORS
    local base = colors.bg_contact_hover
    applyColorTexture(bg, { base[1], base[2], base[3], hovered and HOVER_BG_ALPHA or IDLE_BG_ALPHA })
    if hovered then
      setTextColor(label, colors.text_title or colors.text_primary)
      return
    end
    setTextColor(label, colors.text_primary)
  end

  local function isHovered()
    return button.IsMouseOver and button:IsMouseOver()
  end

  if button.SetScript then
    button:SetScript("OnEnter", function()
      applyVisuals(true)
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(button, "ANCHOR_TOP")
        _G.GameTooltip:SetText(Localization.Text("What's New"))
        if _G.GameTooltip.AddLine then
          pcall(_G.GameTooltip.AddLine, _G.GameTooltip, Localization.Text("See what changed in the latest update."), 1, 1, 1)
        end
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

  local glow = PulseGlow.Create(factory, button, { theme = theme })

  local function setGlowing(glowing)
    if glowing then
      glow.start()
      return
    end
    glow.stop()
  end

  return {
    button = button,
    bg = bg,
    label = label,
    glow = glow,
    setGlowing = setGlowing,
    applyTheme = function(nextTheme)
      theme = nextTheme or Theme
      applyVisuals(isHovered())
      glow.applyTheme(theme)
    end,
  }
end

ns.MessengerWindowChromeBuilderPatchNotesButton = PatchNotesButton

return PatchNotesButton
