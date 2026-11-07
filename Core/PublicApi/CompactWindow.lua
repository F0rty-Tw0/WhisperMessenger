local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- IsCompactWindow(): true when the messenger window is in its compact
-- layout. The layout is fixed for the session (changing the setting reloads
-- the UI), so there is no callback: read it when needed. Once the window is
-- built its real layout wins; before that the saved setting answers, and an
-- unset setting counts as compact. No settings at all, or addon integration
-- off (call refused), gives false.
local CompactWindow = {}

function CompactWindow.Install(api, runtime)
  api.IsCompactWindow = function()
    if runtime.compactLayoutActive ~= nil then
      return runtime.compactLayoutActive == true
    end
    local settings = runtime.accountState and runtime.accountState.settings
    return settings ~= nil and settings.compactLayout ~= false
  end
end

ns.PublicApiCompactWindow = CompactWindow
return CompactWindow
