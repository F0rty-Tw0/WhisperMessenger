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
-- choice and reminds in chat). Reloading into a HUD style starts it on the
-- Azeroth preset, which stays free to change afterwards.
local HudStyleSetting = {}

local QUESTION = "Reload the interface now to apply the new Native WoW HUD style?"
local NOTICE = "Native WoW HUD change requires |cffffff00/reload|r to apply."

local function text(key)
  return Localization and Localization.Text(key) or key
end

-- style: the persisted hudStyle value.
function HudStyleSetting.Apply(accountSettings, style)
  local hudOn = style ~= "off"
  -- nativeChrome mirrors it for older addon versions that only read the
  -- old flag.
  accountSettings.nativeChrome = hudOn
  if Hud.Resolve(style) == Hud.Style() then
    return
  end
  ReloadPrompt.Show(text(QUESTION), function()
    ChatPrint.Print(text(NOTICE))
  end, function()
    if hudOn then
      accountSettings.themePreset = Presets.WOW_NATIVE
    end
  end)
end

ns.BootstrapWindowRuntimeHudStyleSetting = HudStyleSetting
return HudStyleSetting
