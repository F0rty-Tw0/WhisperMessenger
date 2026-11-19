local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")

-- A character the Battle.net lookup did not match is not looked up again
-- (runtime.characterMergeMisses). A change to the Battle.net friend list can
-- make the next lookup match, so it forgets those misses.
local K = "wow::WOW::arthas-area52"

local function newBootstrap()
  return { runtime = { characterMergeMisses = { [K] = true } } }
end

return function()
  local savedTimer = rawget(_G, "C_Timer")
  -- The friend scan stays deferred: these tests only look at the misses.
  rawset(_G, "C_Timer", { After = function() end })

  local ok, err = pcall(function()
    -- test_friend_list_change_forgets_lookup_misses
    do
      local Bootstrap = newBootstrap()
      LifecycleHandlers.Handle(Bootstrap, "BN_FRIEND_LIST_SIZE_CHANGED", { loadModule = require })
      assert(Bootstrap.runtime.characterMergeMisses == nil, "a friend added or loaded late is looked up again")
    end

    -- test_friend_info_change_forgets_lookup_misses
    do
      local Bootstrap = newBootstrap()
      LifecycleHandlers.Handle(Bootstrap, "BN_FRIEND_INFO_CHANGED", { loadModule = require })
      assert(Bootstrap.runtime.characterMergeMisses == nil, "a friend now on that character is looked up again")
    end

    -- test_other_events_keep_lookup_misses
    do
      local Bootstrap = newBootstrap()
      LifecycleHandlers.Handle(Bootstrap, "GROUP_ROSTER_UPDATE", { loadModule = require })
      assert(Bootstrap.runtime.characterMergeMisses[K] == true, "an unrelated event keeps the misses")
    end
  end)

  rawset(_G, "C_Timer", savedTimer)
  assert(ok, err)
end
