local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or (type(require) == "function" and require("WhisperMessenger.Locale.Localization")) or nil
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local ReloadPrompt = ns.ReloadPrompt or require("WhisperMessenger.UI.Shared.ReloadPrompt")
local Presets = ns.ThemePresets or require("WhisperMessenger.UI.Theme.Presets")

-- hudStyle swaps the window's frame templates, which WoW can't do at
-- runtime, so a new style is saved only when the player reloads from the
-- popup; Cancel drops it. Reloading from Off into a HUD style starts it on
-- the Azeroth preset, which stays free to change afterwards; moving between
-- HUD styles keeps the player's preset.
local HudStyleSetting = {}

local QUESTION = "Reload the interface now to apply the new Native WoW HUD style?"
local ELLESMERE_QUESTION = "The EllesmereUI theme shows best with the Native WoW HUD off. Turn it off and reload the interface now?"

-- The style waiting on the reload popup; nil once it is answered or the
-- player goes back to the running style.
local pendingStyle = nil

local function text(key)
  return Localization and Localization.Text(key) or key
end

local function save(accountSettings, style)
  accountSettings.hudStyle = style
  -- nativeChrome mirrors it for older addon versions that only read the
  -- old flag.
  accountSettings.nativeChrome = style ~= "off"
end

-- style: the picked hudStyle. onDiscard(savedStyle) runs on Cancel so the
-- picker can show the saved style again. question: the popup's text, when
-- something other than the HUD picker asks.
function HudStyleSetting.Apply(accountSettings, style, onDiscard, question)
  if Hud.Resolve(style) == Hud.Style() then
    -- Only close our own popup: another setting's may be up.
    local hadPending = pendingStyle ~= nil
    pendingStyle = nil
    save(accountSettings, style)
    if hadPending then
      ReloadPrompt.Hide()
    end
    return
  end
  pendingStyle = style
  ReloadPrompt.Show(text(question or QUESTION), function()
    pendingStyle = nil
    if onDiscard then
      onDiscard(accountSettings.hudStyle)
    end
  end, function()
    -- Read at click time: the choice may have changed while the popup was up.
    local chosen = pendingStyle
    if chosen == nil then
      return
    end
    if not Hud.IsOn() and Hud.Resolve(chosen) ~= "off" then
      accountSettings.themePreset = Presets.WOW_NATIVE
    end
    save(accountSettings, chosen)
  end)
end

-- The HUD's Blizzard frame art hides most of the EllesmereUI theme, so
-- newly picking it under a HUD offers to turn the HUD off. showStyle(style)
-- puts a style on the HUD picker. Re-applying the preset (EllesmereUI look
-- changes) never asks.
function HudStyleSetting.OfferOffFor(accountSettings, previousPreset, presetKey, showStyle)
  if presetKey ~= Presets.ELLESMERE_UI or previousPreset == presetKey or not Hud.IsOn() then
    return false
  end
  showStyle("off")
  HudStyleSetting.Apply(accountSettings, "off", showStyle, ELLESMERE_QUESTION)
  return true
end

ns.BootstrapWindowRuntimeHudStyleSetting = HudStyleSetting
return HudStyleSetting
