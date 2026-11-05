local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local ReloadPrompt = ns.ReloadPrompt or require("WhisperMessenger.UI.Shared.ReloadPrompt")

-- Catalogs other than the active one are released at startup and only come
-- back with a reload, so a pick with no catalog is saved only when the player
-- reloads from the popup; Cancel drops it. Any other pick stays live.
local LanguageSetting = {}

local QUESTION = "Reload the interface now to apply the language change?"

-- The language waiting on the reload popup; nil once it is answered or the
-- player picks a language that can switch live.
local pending = nil

local function isLoaded(localization, value)
  return not localization.IsLanguageLoaded or localization.IsLanguageLoaded(value)
end

-- Returns true when the prompt took over and the caller must not save.
function LanguageSetting.Apply(accountSettings, value, runtime, localization)
  if isLoaded(localization, value) then
    -- Only close our own popup: another setting's may be up.
    if pending ~= nil then
      pending = nil
      ReloadPrompt.Hide()
    end
    return false
  end
  pending = value or "auto"
  ReloadPrompt.Show(Localization.Text(QUESTION), function()
    pending = nil
    -- The selector already moved to the pick, so show the saved value again.
    local window = runtime.window
    if window and window.refreshLanguage then
      window.refreshLanguage(accountSettings.interfaceLanguage or "auto")
    end
  end, function()
    -- Read at click time: the choice may have changed while the popup was up.
    if pending == nil then
      return
    end
    accountSettings.interfaceLanguage = pending
    pending = nil
  end)
  return true
end

ns.BootstrapWindowRuntimeLanguageSetting = LanguageSetting
return LanguageSetting
