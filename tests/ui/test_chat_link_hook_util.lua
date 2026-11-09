-- OnAddOnLoaded runs a hook group once its Blizzard addon has loaded. Hooks are
-- registered while our composer is built, so a throw there (an addon the
-- flavor does not have, a hook that trips) must not escape.
local Util = require("WhisperMessenger.UI.Composer.ChatLinkHookUtil")

local function withEventUtil(eventUtil, fn)
  local saved = rawget(_G, "EventUtil")
  rawset(_G, "EventUtil", eventUtil)
  local ok, err = pcall(fn)
  rawset(_G, "EventUtil", saved)
  if not ok then
    error(err, 0)
  end
end

return function()
  -- test_on_addon_loaded_waits_for_the_addon
  withEventUtil({
    ContinueOnAddOnLoaded = function(name, callback)
      assert(name == "Blizzard_GlyphUI", "expected the addon name, got " .. tostring(name))
      callback()
    end,
  }, function()
    local ran = false
    Util.OnAddOnLoaded("Blizzard_GlyphUI", function()
      ran = true
    end)
    assert(ran, "the callback should run once the addon has loaded")
  end)

  -- test_on_addon_loaded_contains_a_throwing_event_util
  withEventUtil({
    ContinueOnAddOnLoaded = function()
      error("unknown addon")
    end,
  }, function()
    local ok, err = pcall(Util.OnAddOnLoaded, "Blizzard_GlyphUI", function() end)
    assert(ok, "a throw from ContinueOnAddOnLoaded must not escape: " .. tostring(err))
  end)

  -- test_on_addon_loaded_contains_a_throwing_deferred_callback
  -- (EventUtil runs the callback later, from its own event handler)
  local deferred
  withEventUtil({
    ContinueOnAddOnLoaded = function(_name, callback)
      deferred = callback
    end,
  }, function()
    Util.OnAddOnLoaded("Blizzard_GlyphUI", function()
      error("hook tripped")
    end)
  end)
  local deferredOk, deferredErr = pcall(deferred)
  assert(deferredOk, "a throw from a deferred callback must not escape: " .. tostring(deferredErr))

  -- test_on_addon_loaded_contains_a_throwing_callback_without_event_util
  withEventUtil(nil, function()
    local ok, err = pcall(Util.OnAddOnLoaded, "Blizzard_GlyphUI", function()
      error("hook tripped")
    end)
    assert(ok, "a throw from the callback must not escape: " .. tostring(err))
  end)
end
