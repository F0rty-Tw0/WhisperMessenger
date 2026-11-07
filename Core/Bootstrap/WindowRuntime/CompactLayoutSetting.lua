local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or (type(require) == "function" and require("WhisperMessenger.Locale.Localization")) or nil
local ReloadPrompt = ns.ReloadPrompt or require("WhisperMessenger.UI.Shared.ReloadPrompt")

-- The window is built for one style, so a new style is saved only when the
-- player reloads from the popup; Cancel drops it.
local CompactLayoutSetting = {}

local QUESTION = "Reload the interface now to switch the window style?"

-- The style waiting on the reload popup; nil once it is answered or the
-- player goes back to the running style.
local pendingStyle = nil

local function text(key)
  return Localization and Localization.Text(key) or key
end

-- enabled: the toggle's new state. running: the style this session was built
-- with. onDiscard(saved) runs on Cancel so the toggle can show the saved style
-- again.
function CompactLayoutSetting.Apply(accountSettings, enabled, running, onDiscard)
  if enabled == running then
    -- Only close our own popup: another setting's may be up.
    local hadPending = pendingStyle ~= nil
    pendingStyle = nil
    accountSettings.compactLayout = enabled
    if hadPending then
      ReloadPrompt.Hide()
    end
    return
  end
  pendingStyle = enabled
  ReloadPrompt.Show(text(QUESTION), function()
    pendingStyle = nil
    if onDiscard then
      onDiscard(accountSettings.compactLayout ~= false)
    end
  end, function()
    -- Read at click time: the choice may have changed while the popup was up.
    if pendingStyle ~= nil then
      accountSettings.compactLayout = pendingStyle
    end
  end)
end

ns.BootstrapWindowRuntimeCompactLayoutSetting = CompactLayoutSetting
return CompactLayoutSetting
