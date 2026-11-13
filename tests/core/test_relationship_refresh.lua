local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local RelationshipRefresh = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.RelationshipRefresh")
local Constants = require("WhisperMessenger.Core.Constants")

local INVALIDATING = { "CLUB_MEMBER_ADDED", "CLUB_MEMBER_REMOVED", "PLAYER_GUILD_UPDATE", "FRIENDLIST_UPDATE", "BN_FRIEND_LIST_SIZE_CHANGED" }
local QUIET = { "BN_FRIEND_INFO_CHANGED", "GUILD_ROSTER_UPDATE", "CLUB_MEMBER_UPDATED" }
-- No presence cache: the existing presence handlers return early and cannot add repaints of their own.
local deps = { getContentDetector = function() end, getPresenceCache = function() end }

return function()
  local savedCTimer = rawget(_G, "C_Timer")

  local function captureTimers()
    local scheduled = {}
    rawset(_G, "C_Timer", {
      After = function(delay, fn)
        scheduled[#scheduled + 1] = { delay = delay, fn = fn }
      end,
    })
    return scheduled
  end

  -- stale is the cache table Invalidate must replace.
  local function build(runtimeExtras)
    local state = { repaints = 0, stale = { ["wow::a"] = { value = false, at = 1 } } }
    local runtime = {
      relationshipCache = state.stale,
      accountState = { settings = {} },
      refreshWindow = function()
        state.repaints = state.repaints + 1
      end,
    }
    for key, value in pairs(runtimeExtras or {}) do
      runtime[key] = value
    end
    return { runtime = runtime }, state
  end

  -- test_registered_for_guild_updates_but_not_kept_during_mythic_lockdown
  do
    local found = false
    for _, name in ipairs(Constants.LIFECYCLE_EVENT_NAMES) do
      found = found or name == "PLAYER_GUILD_UPDATE"
    end
    assert(found, "PLAYER_GUILD_UPDATE must be a lifecycle event")
    assert(Constants.MYTHIC_ESSENTIAL_EVENTS.PLAYER_GUILD_UPDATE == nil, "it is unregistered while suspended")
  end

  -- test_each_membership_event_invalidates_through_the_lifecycle_router
  for _, event in ipairs(INVALIDATING) do
    captureTimers()
    local Bootstrap, state = build()
    local handled = LifecycleHandlers.Handle(Bootstrap, event, deps)
    assert(Bootstrap.runtime.relationshipCache ~= state.stale, event .. " should drop the relationship cache")
    if event == "PLAYER_GUILD_UPDATE" then
      assert(handled == true, "PLAYER_GUILD_UPDATE stops in the lifecycle router")
    end
  end

  -- test_churny_events_never_invalidate
  for _, event in ipairs(QUIET) do
    captureTimers()
    local Bootstrap, state = build()
    LifecycleHandlers.Handle(Bootstrap, event, deps)
    assert(Bootstrap.runtime.relationshipCache == state.stale, event .. " must not drop the relationship cache")
  end
  for _, event in ipairs(QUIET) do
    local scheduled = captureTimers()
    local Bootstrap = build()
    assert(RelationshipRefresh.handle(Bootstrap, event) == false and #scheduled == 0, event .. " schedules no relationship repaint")
  end

  -- test_burst_repaints_once_two_seconds_after_the_last_event
  for _, event in ipairs(INVALIDATING) do
    local scheduled = captureTimers()
    local Bootstrap, state = build()
    for _ = 1, 3 do
      RelationshipRefresh.handle(Bootstrap, event)
    end
    assert(#scheduled >= 1 and scheduled[#scheduled].delay == 2, event .. " repaints after 2 s")
    for index = 1, #scheduled - 1 do
      scheduled[index].fn()
    end
    assert(state.repaints == 0, event .. ": earlier timers of the burst must not repaint")
    scheduled[#scheduled].fn()
    assert(state.repaints == 1, event .. ": exactly one repaint per burst, got " .. state.repaints)
  end

  -- test_next_burst_repaints_again
  do
    local scheduled = captureTimers()
    local Bootstrap, state = build()
    RelationshipRefresh.handle(Bootstrap, "FRIENDLIST_UPDATE")
    scheduled[#scheduled].fn()
    RelationshipRefresh.handle(Bootstrap, "CLUB_MEMBER_ADDED")
    scheduled[#scheduled].fn()
    assert(state.repaints == 2, "two bursts, two repaints, got " .. state.repaints)
  end

  -- test_no_repaint_in_mythic_content_but_cache_still_drops
  do
    local scheduled = captureTimers()
    local Bootstrap, state = build()
    Bootstrap._inMythicContent = true
    RelationshipRefresh.handle(Bootstrap, "CLUB_MEMBER_REMOVED")
    assert(Bootstrap.runtime.relationshipCache ~= state.stale, "the cache still drops")
    assert(#scheduled == 0 and state.repaints == 0, "nothing is scheduled in mythic content")
  end

  -- test_mythic_content_starting_before_the_timer_fires_skips_the_repaint
  do
    local scheduled = captureTimers()
    local Bootstrap, state = build()
    RelationshipRefresh.handle(Bootstrap, "FRIENDLIST_UPDATE")
    Bootstrap._inMythicContent = true
    scheduled[#scheduled].fn()
    assert(state.repaints == 0, "no repaint once mythic content began")
  end

  -- test_setting_off_invalidates_without_repaint
  do
    local scheduled = captureTimers()
    local Bootstrap, state = build()
    Bootstrap.runtime.accountState.settings.showRelationshipMarks = false
    RelationshipRefresh.handle(Bootstrap, "FRIENDLIST_UPDATE")
    assert(Bootstrap.runtime.relationshipCache ~= state.stale, "the cache still drops")
    assert(#scheduled == 0 and state.repaints == 0, "marks off: no repaint")
  end

  -- test_closed_window_invalidates_without_repaint
  do
    local scheduled = captureTimers()
    local Bootstrap, state = build({
      isWindowVisible = function()
        return false
      end,
    })
    RelationshipRefresh.handle(Bootstrap, "FRIENDLIST_UPDATE")
    assert(Bootstrap.runtime.relationshipCache ~= state.stale, "the cache still drops")
    assert(#scheduled == 0 and state.repaints == 0, "closed window repaints on open, not now")
  end

  -- test_without_timers_repaints_at_once
  do
    rawset(_G, "C_Timer", nil)
    local Bootstrap, state = build()
    RelationshipRefresh.handle(Bootstrap, "CLUB_MEMBER_ADDED")
    assert(state.repaints == 1, "no timer API: repaint synchronously, got " .. state.repaints)
  end

  -- test_guild_update_for_another_unit_is_ignored
  do
    local scheduled = captureTimers()
    local Bootstrap, state = build()
    assert(RelationshipRefresh.handle(Bootstrap, "PLAYER_GUILD_UPDATE", "party1") == false, "another unit's guild change is not ours")
    assert(Bootstrap.runtime.relationshipCache == state.stale and #scheduled == 0, "nothing happens for another unit")
    assert(RelationshipRefresh.handle(Bootstrap, "PLAYER_GUILD_UPDATE", "player") == true, "the player's own change counts")
    assert(RelationshipRefresh.handle(Bootstrap, "PLAYER_GUILD_UPDATE") == true, "no unit counts too")
  end

  -- test_friendlist_update_invalidates_only_when_the_friend_count_changes
  do
    local savedFriendList = rawget(_G, "C_FriendList")
    local count = 5
    rawset(_G, "C_FriendList", {
      GetNumFriends = function()
        return count
      end,
    })
    local scheduled = captureTimers()
    local Bootstrap, state = build()
    assert(RelationshipRefresh.handle(Bootstrap, "FRIENDLIST_UPDATE") == true, "the first count is new")
    local kept = Bootstrap.runtime.relationshipCache
    local timers = #scheduled
    assert(RelationshipRefresh.handle(Bootstrap, "FRIENDLIST_UPDATE") == false, "same count: a status change, not a membership change")
    assert(Bootstrap.runtime.relationshipCache == kept and #scheduled == timers, "same count keeps the cache and schedules nothing")
    count = 6
    assert(RelationshipRefresh.handle(Bootstrap, "FRIENDLIST_UPDATE") == true, "a new count invalidates")
    assert(Bootstrap.runtime.relationshipCache ~= kept and #scheduled == timers + 1, "a new count drops the cache and repaints")
    assert(RelationshipRefresh.handle(Bootstrap, "CLUB_MEMBER_ADDED") == true, "other events ignore the friend count")
    assert(state.repaints == 0, "nothing fired yet")
    rawset(_G, "C_FriendList", savedFriendList)
  end

  -- test_friendlist_update_with_a_throwing_count_still_invalidates
  do
    local savedFriendList = rawget(_G, "C_FriendList")
    rawset(_G, "C_FriendList", {
      GetNumFriends = function()
        error("friend list not ready")
      end,
    })
    captureTimers()
    local Bootstrap = build()
    RelationshipRefresh.handle(Bootstrap, "FRIENDLIST_UPDATE")
    local kept = Bootstrap.runtime.relationshipCache
    assert(RelationshipRefresh.handle(Bootstrap, "FRIENDLIST_UPDATE") == true, "an unreadable count invalidates every time")
    assert(Bootstrap.runtime.relationshipCache ~= kept, "the cache drops")
    rawset(_G, "C_FriendList", savedFriendList)
  end

  -- test_no_runtime_is_harmless
  do
    captureTimers()
    assert(RelationshipRefresh.handle({}, "FRIENDLIST_UPDATE") == false, "no runtime: nothing to do")
    LifecycleHandlers.Handle({}, "PLAYER_GUILD_UPDATE", deps)
  end

  rawset(_G, "C_Timer", savedCTimer)
end
