local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local PulseGlow = ns.ToggleIconPulseGlow or require("WhisperMessenger.UI.ToggleIcon.PulseGlow")
local IconButtonStyle = ns.MessengerWindowChromeBuilderIconButtonStyle or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.IconButtonStyle")
local applyVertexColor = UIHelpers.applyVertexColor

local PatchNotesButton = {}

-- Creates the What's New title-bar button (sparkle icon). Size and anchor come from TitleBarLayout. It pulses while the
-- shipped patch-notes version has not been seen yet (setGlowing).
function PatchNotesButton.Create(factory, frame, theme)
  theme = theme or Theme

  local button = factory.CreateFrame("Button", nil, frame)

  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(button)
  IconButtonStyle.Attach(button, bg)

  local icon = button:CreateTexture(nil, "ARTWORK")
  IconButtonStyle.SetGlyph(button, icon, theme.TEXTURES.title_whats_new_icon)
  icon:SetSize(theme.LAYOUT.CHROME_BUTTON_ICON_SIZE, theme.LAYOUT.CHROME_BUTTON_ICON_SIZE)
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)

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
