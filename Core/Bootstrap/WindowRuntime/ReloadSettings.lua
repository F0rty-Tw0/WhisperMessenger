local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local ReloadPrompt = ns.ReloadPrompt or require("WhisperMessenger.UI.Shared.ReloadPrompt")
local Presets = ns.ThemePresets or require("WhisperMessenger.UI.Theme.Presets")

-- Settings whose change may need a reload. When it does, the new value waits
-- on the reload popup and is saved only if the player reloads. One table per
-- setting, called by SettingsHandler.
local ReloadSettings = {}

local function text(key)
  return Localization.Text(key)
end

-- The window is built for one style, so a new style is saved only when the
-- player reloads from the popup; Cancel drops it.
local CompactLayoutSetting = {}

local COMPACT_LAYOUT_QUESTION = "Reload the interface now to switch the window style?"

-- The style waiting on the reload popup; nil once it is answered or the
-- player goes back to the running style.
local pendingCompactLayout = nil

-- enabled: the toggle's new state. running: the style this session was built
-- with. onDiscard(saved) runs on Cancel so the toggle can show the saved style
-- again.
function CompactLayoutSetting.Apply(accountSettings, enabled, running, onDiscard)
  if enabled == running then
    -- Only close our own popup: another setting's may be up.
    local hadPending = pendingCompactLayout ~= nil
    pendingCompactLayout = nil
    accountSettings.compactLayout = enabled
    if hadPending then
      ReloadPrompt.Hide()
    end
    return
  end
  pendingCompactLayout = enabled
  ReloadPrompt.Show(text(COMPACT_LAYOUT_QUESTION), function()
    pendingCompactLayout = nil
    if onDiscard then
      onDiscard(accountSettings.compactLayout ~= false)
    end
  end, function()
    -- Read at click time: the choice may have changed while the popup was up.
    if pendingCompactLayout ~= nil then
      accountSettings.compactLayout = pendingCompactLayout
    end
  end)
end

-- Catalogs other than the active one are released at startup and only come
-- back with a reload, so a pick with no catalog is saved only when the player
-- reloads from the popup; Cancel drops it. Any other pick stays live.
local LanguageSetting = {}

local LANGUAGE_QUESTION = "Reload the interface now to apply the language change?"

-- The language waiting on the reload popup; nil once it is answered or the
-- player picks a language that can switch live.
local pendingLanguage = nil

local function isLoaded(localization, value)
  return not localization.IsLanguageLoaded or localization.IsLanguageLoaded(value)
end

-- Returns true when the prompt took over and the caller must not save.
function LanguageSetting.Apply(accountSettings, value, runtime, localization)
  if isLoaded(localization, value) then
    -- Only close our own popup: another setting's may be up.
    if pendingLanguage ~= nil then
      pendingLanguage = nil
      ReloadPrompt.Hide()
    end
    return false
  end
  pendingLanguage = value or "auto"
  ReloadPrompt.Show(Localization.Text(LANGUAGE_QUESTION), function()
    pendingLanguage = nil
    -- The selector already moved to the pick, so show the saved value again.
    local window = runtime.window
    if window and window.refreshLanguage then
      window.refreshLanguage(accountSettings.interfaceLanguage or "auto")
    end
  end, function()
    -- Read at click time: the choice may have changed while the popup was up.
    if pendingLanguage == nil then
      return
    end
    accountSettings.interfaceLanguage = pendingLanguage
    pendingLanguage = nil
  end)
  return true
end

-- allowAddonIntegration is read once at load (the public API is built from
-- it), so a change is saved only when the player reloads from the popup;
-- Cancel drops it. The saved value is the running one: it only ever moves
-- to the other value right before a reload.
local IntegrationSetting = {}

local INTEGRATION_QUESTION = "Reload the interface now to apply the addon integration change?"

-- The value waiting on the reload popup; nil once it is answered or the
-- player goes back to the running value.
local pendingIntegration = nil

local function isAllowed(accountSettings)
  return accountSettings.allowAddonIntegration ~= false
end

-- On Cancel the Behavior page shows the saved value again.
local function showSaved(runtime, accountSettings)
  local behavior = runtime.window and runtime.window.behaviorSettings
  if behavior and behavior.setAllowAddonIntegration then
    behavior.setAllowAddonIntegration(isAllowed(accountSettings))
  end
end

function IntegrationSetting.Apply(accountSettings, allowed, runtime)
  allowed = allowed ~= false
  if allowed == isAllowed(accountSettings) then
    accountSettings.allowAddonIntegration = allowed
    -- Only close our own popup: another setting's may be up.
    if pendingIntegration ~= nil then
      pendingIntegration = nil
      ReloadPrompt.Hide()
    end
    return
  end
  pendingIntegration = allowed
  ReloadPrompt.Show(text(INTEGRATION_QUESTION), function()
    pendingIntegration = nil
    showSaved(runtime or {}, accountSettings)
  end, function()
    -- Read at click time: the choice may have changed while the popup was up.
    if pendingIntegration == nil then
      return
    end
    accountSettings.allowAddonIntegration = pendingIntegration
  end)
end

-- hudStyle swaps the window's frame templates, which WoW can't do at
-- runtime, so a new style is saved only when the player reloads from the
-- popup; Cancel drops it. Reloading from Off into a HUD style starts it on
-- the Azeroth preset, which stays free to change afterwards; moving between
-- HUD styles keeps the player's preset.
local HudStyleSetting = {}

local HUD_QUESTION = "Reload the interface now to apply the new Native WoW HUD style?"
local ELLESMERE_QUESTION = "The EllesmereUI theme shows best with the Native WoW HUD off. Turn it off and reload the interface now?"

-- The style waiting on the reload popup; nil once it is answered or the
-- player goes back to the running style.
local pendingHudStyle = nil

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
    local hadPending = pendingHudStyle ~= nil
    pendingHudStyle = nil
    save(accountSettings, style)
    if hadPending then
      ReloadPrompt.Hide()
    end
    return
  end
  pendingHudStyle = style
  ReloadPrompt.Show(text(question or HUD_QUESTION), function()
    pendingHudStyle = nil
    if onDiscard then
      onDiscard(accountSettings.hudStyle)
    end
  end, function()
    -- Read at click time: the choice may have changed while the popup was up.
    local chosen = pendingHudStyle
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

ReloadSettings.CompactLayoutSetting = CompactLayoutSetting
ReloadSettings.LanguageSetting = LanguageSetting
ReloadSettings.IntegrationSetting = IntegrationSetting
ReloadSettings.HudStyleSetting = HudStyleSetting

ns.BootstrapWindowRuntimeReloadSettings = ReloadSettings
return ReloadSettings
