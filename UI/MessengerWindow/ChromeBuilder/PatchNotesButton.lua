local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local PulseGlow = ns.ToggleIconPulseGlow or require("WhisperMessenger.UI.ToggleIcon.PulseGlow")
local Buttons = ns.MessengerWindowChromeBuilderButtons or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.Buttons")

local PatchNotesButton = {}

-- Creates the What's New title-bar button (scroll icon). Size and anchor come from TitleBarLayout. It pulses while the
-- shipped patch-notes version has not been seen yet (setGlowing).
function PatchNotesButton.Create(factory, frame, theme)
  theme = theme or Theme

  local base = Buttons.CreatePlainIcon(factory, frame, theme, "title_whats_new_icon", "What's New", {
    hintKey = "See what changed in the latest update.",
  })
  local button = base.button

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
      base.applyTheme(nextTheme)
      glow.applyTheme(nextTheme or Theme)
    end,
  }
end

ns.MessengerWindowChromeBuilderPatchNotesButton = PatchNotesButton

return PatchNotesButton
