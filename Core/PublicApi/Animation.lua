local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- IsAnimationEnabled(): true unless the player turned "Window animation"
-- off. Read at call time, so it follows the setting; a missing setting counts
-- as on. With addon integration off the call is refused and returns false.
local Animation = {}

function Animation.Install(api, runtime)
  api.IsAnimationEnabled = function()
    local settings = runtime.accountState and runtime.accountState.settings
    return not settings or settings.windowAnimation ~= false
  end
end

ns.PublicApiAnimation = Animation
return Animation
