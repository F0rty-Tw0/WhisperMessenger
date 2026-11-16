-- The restriction instance owns the pre-12.0 detection flags next to the
-- 12.0 event cache, and answers "restricted?" from both.
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")

local TYPES = RestrictedActions.TYPES
local STATES = RestrictedActions.STATES

-- No restriction API and the given chat-lock answer, for the length of fn.
local function withChatLock(locked, fn)
  local savedChatInfo = rawget(_G, "C_ChatInfo")
  local savedRestricted = rawget(_G, "C_RestrictedActions")
  rawset(_G, "C_RestrictedActions", nil)
  rawset(_G, "C_ChatInfo", {
    InChatMessagingLockdown = function()
      return locked
    end,
  })
  local ok, err = pcall(fn)
  rawset(_G, "C_ChatInfo", savedChatInfo)
  rawset(_G, "C_RestrictedActions", savedRestricted)
  assert(ok, err)
end

return function()
  -- test_flags_default_false
  withChatLock(false, function()
    local instance = RestrictedActions.New()
    for _, name in ipairs({ "mythic", "competitive", "encounter" }) do
      assert(instance.flag(name) == false, name .. " flag must start false")
    end
    assert(instance.isMythic() == false, "no flag, no cache: not mythic")
    assert(instance.isCompetitive() == false, "no flag, no cache, no chat lock: not competitive")
    assert(instance.isRestricted() == false, "no flag, no cache, no chat lock: not restricted")
  end)

  -- test_flag_mythic_counts_as_mythic
  withChatLock(false, function()
    local instance = RestrictedActions.New()
    instance.setFlag("mythic", true)
    assert(instance.flag("mythic") == true, "the flag reads back")
    assert(instance.isMythic() == true, "the mythic flag counts as mythic without any cached event")
    assert(instance.isCompetitive() == false, "the mythic flag alone is not competitive")
    assert(instance.isRestricted() == true, "mythic is restricted")
    instance.setFlag("mythic", false)
    assert(instance.isMythic() == false, "clearing the flag clears mythic")
  end)

  -- test_flag_encounter_counts_as_competitive
  withChatLock(false, function()
    local instance = RestrictedActions.New()
    instance.setFlag("encounter", true)
    assert(instance.isCompetitive() == true, "the encounter flag counts as competitive")
    assert(instance.isMythic() == false, "the encounter flag is not mythic")
  end)

  -- test_flag_competitive_counts_as_competitive
  withChatLock(false, function()
    local instance = RestrictedActions.New()
    instance.setFlag("competitive", true)
    assert(instance.isCompetitive() == true, "the competitive flag counts as competitive")
  end)

  -- test_chat_lock_counts_as_competitive
  withChatLock(true, function()
    local instance = RestrictedActions.New()
    assert(instance.isCompetitive() == true, "a chat lock behaves like competitive content")
    assert(instance.isMythic() == false, "a chat lock is not mythic")
  end)

  -- test_is_restricted_true_when_only_cache_reports_encounter
  withChatLock(false, function()
    local instance = RestrictedActions.New()
    instance.updateFromEvent(TYPES.Encounter, STATES.Active)
    assert(instance.flag("encounter") == false, "the cache does not set the flag")
    assert(instance.isRestricted() == true, "a cached encounter alone is restricted")
  end)

  -- test_any_truthy_value_sets_a_flag
  withChatLock(false, function()
    local store = {}
    local instance = RestrictedActions.New(store)
    instance.setFlag("mythic", 1)
    assert(instance.flag("mythic") == true, "a truthy value sets the flag, so no reader can take it for unset")
    assert(instance.isMythic() == true, "a truthy flag value is mythic")
    assert(store._inMythicContent == true, "the store holds a boolean, got " .. tostring(store._inMythicContent))
    instance.setFlag("mythic", nil)
    assert(store._inMythicContent == false, "nil clears the flag to false, got " .. tostring(store._inMythicContent))
  end)

  -- test_truthy_value_already_in_the_store_reads_as_set
  withChatLock(false, function()
    local instance = RestrictedActions.New({ _inEncounter = 1 })
    assert(instance.flag("encounter") == true, "a truthy field in the store reads as a set flag")
  end)

  -- test_unknown_flag_name_is_rejected
  withChatLock(false, function()
    local instance = RestrictedActions.New()
    local readOk, readErr = pcall(instance.flag, "typo")
    assert(readOk == false, "reading an unknown flag must fail, not answer false")
    assert(string.find(tostring(readErr), "typo", 1, true), "the error names the flag, got " .. tostring(readErr))
    local writeOk, writeErr = pcall(instance.setFlag, "typo", true)
    assert(writeOk == false, "writing an unknown flag must fail")
    assert(string.find(tostring(writeErr), "unknown restriction flag", 1, true), "the error says what is wrong, got " .. tostring(writeErr))
    assert(string.find(tostring(writeErr), "typo", 1, true), "the error names the flag, got " .. tostring(writeErr))
  end)

  -- test_for_returns_the_instance_the_owner_holds
  withChatLock(false, function()
    local instance = RestrictedActions.New()
    local owner = { restrictions = instance }
    assert(RestrictedActions.For(owner) == instance, "For must hand back the owner's instance")
  end)

  -- test_for_gives_an_owner_without_an_instance_one_over_its_own_flags
  withChatLock(false, function()
    local owner = { _inMythicContent = true }
    local instance = RestrictedActions.For(owner)
    assert(owner.restrictions == instance, "the new instance is kept on the owner")
    assert(RestrictedActions.For(owner) == instance, "a second ask returns the same instance")
    assert(instance.flag("mythic") == true, "the owner's own flag fields are the store")
    instance.setFlag("encounter", true)
    assert(owner._inEncounter == true, "flags are written to the owner")
  end)

  -- test_flags_live_in_the_given_store
  withChatLock(false, function()
    local store = { _inEncounter = true }
    local instance = RestrictedActions.New(store)
    assert(instance.flag("encounter") == true, "a flag already in the store is read")
    instance.setFlag("mythic", true)
    instance.setFlag("competitive", false)
    assert(store._inMythicContent == true, "setFlag writes the mythic field of the store")
    assert(store._inCompetitiveContent == false, "setFlag writes the competitive field of the store")
    store._inMythicContent = nil
    assert(instance.isMythic() == false, "a field cleared in the store clears the flag")
  end)

  -- test_instances_do_not_share_flags
  withChatLock(false, function()
    local first, second = RestrictedActions.New(), RestrictedActions.New()
    first.setFlag("mythic", true)
    assert(second.flag("mythic") == false, "each instance without a store keeps its own flags")
  end)
end
