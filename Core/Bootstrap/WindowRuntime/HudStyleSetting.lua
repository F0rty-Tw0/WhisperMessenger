local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or (type(require) == "function" and require("WhisperMessenger.Locale.Localization")) or nil
local ChatPrint = ns.ChatPrint or require("WhisperMessenger.Util.ChatPrint")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local ReloadPrompt = ns.ReloadPrompt or require("WhisperMessenger.UI.Shared.ReloadPrompt")
local Presets = ns.ThemePresets or require("WhisperMessenger.UI.Theme.Presets")

-- hudStyle swaps the window's frame templates, which WoW can't do at
-- runtime, so it applies after a reload: offer one now (Cancel keeps the
-- choice and reminds in chat). Reloading from Off into a HUD style starts it
-- on the Azeroth preset, which stays free to change afterwards; moving
-- between HUD styles keeps the player's preset.
local HudStyleSetting = {}

local QUESTION = "Reload the interface now to apply the new Native WoW HUD style?"
local NOTICE = "Native WoW HUD change requires |cffffff00/reload|r to apply."

local function text(key)
  return Localization and Localization.Text(key) or key
end

-- style: the persisted hudStyle value.
function HudStyleSetting.Apply(accountSettings, style)
  -- nativeChrome mirrors it for older addon versions that only read the
  -- old flag.
  accountSettings.nativeChrome = style ~= "off"
  if Hud.Resolve(style) == Hud.Style() then
    ReloadPrompt.Hide()
    return
  end
  ReloadPrompt.Show(text(QUESTION), function()
    ChatPrint.Print(text(NOTICE))
  end, function()
    -- Read at click time: the choice may have changed while the popup was up.
    if not Hud.IsOn() and Hud.Resolve(accountSettings.hudStyle) ~= "off" then
      accountSettings.themePreset = Presets.WOW_NATIVE
    end
  end)
end

ns.BootstrapWindowRuntimeHudStyleSetting = HudStyleSetting
return HudStyleSetting
