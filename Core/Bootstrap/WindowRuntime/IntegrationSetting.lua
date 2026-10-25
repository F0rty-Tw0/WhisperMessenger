local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or (type(require) == "function" and require("WhisperMessenger.Locale.Localization")) or nil
local ReloadPrompt = ns.ReloadPrompt or require("WhisperMessenger.UI.Shared.ReloadPrompt")

-- allowAddonIntegration is read once at load (the public API is built from
-- it), so a change is saved only when the player reloads from the popup;
-- Cancel drops it. The saved value is the running one: it only ever moves
-- to the other value right before a reload.
local IntegrationSetting = {}

local QUESTION = "Reload the interface now to apply the addon integration change?"

-- The value waiting on the reload popup; nil once it is answered or the
-- player goes back to the running value.
local pending = nil

local function text(key)
  return Localization and Localization.Text(key) or key
end

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
    if pending ~= nil then
      pending = nil
      ReloadPrompt.Hide()
    end
    return
  end
  pending = allowed
  ReloadPrompt.Show(text(QUESTION), function()
    pending = nil
    showSaved(runtime or {}, accountSettings)
  end, function()
    -- Read at click time: the choice may have changed while the popup was up.
    if pending == nil then
      return
    end
    accountSettings.allowAddonIntegration = pending
  end)
end

ns.BootstrapWindowRuntimeIntegrationSetting = IntegrationSetting
return IntegrationSetting
