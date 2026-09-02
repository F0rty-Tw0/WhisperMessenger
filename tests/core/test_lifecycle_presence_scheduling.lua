local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local ContentDetector = require("WhisperMessenger.Core.ContentDetector")

return function()
  local savedGetInstanceInfo = _G.GetInstanceInfo
  local savedCTimer = _G.C_Timer

  local function makeSpyCache()
    local calls = { invalidate = 0, rebuild = 0 }
    return calls,
      {
        Invalidate = function()
          calls.invalidate = calls.invalidate + 1
        end,
        Rebuild = function()
          calls.rebuild = calls.rebuild + 1
        end,
        IsStale = function()
          return true
        end,
        GetTTL = function()
          return 30
        end,
      }
  end

  local function captureTimers()
    local scheduled = {}
    _G.C_Timer = {
      After = function(delay, fn)
        scheduled[#scheduled + 1] = { delay = delay, fn = fn }
      end,
    }
    return scheduled
  end

  -- A roster or club membership change only marks presence data stale; it
  -- never schedules a full guild/community rescan.
  do
    local events = { "GUILD_ROSTER_UPDATE", "CLUB_MEMBER_UPDATED", "CLUB_MEMBER_ADDED", "CLUB_MEMBER_REMOVED" }
    for _, event in ipairs(events) do
      local scheduled = captureTimers()
      local calls, presenceCache = makeSpyCache()
      local Bootstrap = { runtime = {} }
      local deps = {
        getContentDetector = function()
          return ContentDetector
        end,
        getPresenceCache = function()
          return presenceCache
        end,
      }

      LifecycleHandlers.Handle(Bootstrap, event, deps)

      assert(calls.invalidate == 1, event .. " should invalidate presence once, got " .. calls.invalidate)
      assert(calls.rebuild == 0, event .. " must not rebuild presence, got " .. calls.rebuild)
      assert(#scheduled == 0, event .. " must not schedule a presence timer, got " .. #scheduled)
      assert(Bootstrap._presenceRebuildPending == nil, event .. " must not leave a pending-rebuild flag behind")
    end
  end

  -- Bursts of roster events stay cheap: still no rebuild, still no timers.
  do
    local scheduled = captureTimers()
    local calls, presenceCache = makeSpyCache()
    local Bootstrap = { runtime = {} }
    local deps = {
      getContentDetector = function()
        return ContentDetector
      end,
      getPresenceCache = function()
        return presenceCache
      end,
    }

    for _ = 1, 20 do
      LifecycleHandlers.Handle(Bootstrap, "GUILD_ROSTER_UPDATE", deps)
    end

    assert(calls.invalidate == 20, "each roster event should invalidate, got " .. calls.invalidate)
    assert(calls.rebuild == 0, "a burst of roster events must not rebuild presence, got " .. calls.rebuild)
    assert(#scheduled == 0, "a burst of roster events must not schedule timers, got " .. #scheduled)
  end

  -- Entering the world schedules exactly one presence rebuild and starts no
  -- repeating refresh loop.
  do
    rawset(_G, "GetInstanceInfo", function()
      return "Orgrimmar", "none", 0
    end)

    local scheduled = captureTimers()
    local calls, presenceCache = makeSpyCache()
    local Bootstrap = { runtime = { suspend = function() end, resume = function() end } }
    local deps = {
      getContentDetector = function()
        return ContentDetector
      end,
      getPresenceCache = function()
        return presenceCache
      end,
    }

    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", deps)

    assert(#scheduled == 1, "entering the world should schedule one presence rebuild, got " .. #scheduled)
    assert(scheduled[1].delay == 2, "the initial presence rebuild should be the short one-shot, got " .. tostring(scheduled[1].delay))

    scheduled[1].fn()
    assert(calls.rebuild == 1, "the scheduled callback should rebuild presence once, got " .. calls.rebuild)
    assert(#scheduled == 1, "the presence rebuild must not reschedule itself, got " .. #scheduled)
  end

  -- Repeated PLAYER_ENTERING_WORLD events never accumulate a refresh loop.
  do
    rawset(_G, "GetInstanceInfo", function()
      return "Orgrimmar", "none", 0
    end)

    local scheduled = captureTimers()
    local calls, presenceCache = makeSpyCache()
    local Bootstrap = { runtime = { suspend = function() end, resume = function() end } }
    local deps = {
      getContentDetector = function()
        return ContentDetector
      end,
      getPresenceCache = function()
        return presenceCache
      end,
    }

    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", deps)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", deps)

    local index = 1
    while index <= #scheduled do
      local call = scheduled[index]
      assert(call.delay == 2, "presence scheduling should only use the one-shot delay, got " .. tostring(call.delay))
      call.fn()
      index = index + 1
    end

    assert(#scheduled == 2, "each entering-world event should schedule one rebuild, got " .. #scheduled)
    assert(calls.rebuild == 2, "each scheduled rebuild should run once, got " .. calls.rebuild)
  end

  rawset(_G, "GetInstanceInfo", savedGetInstanceInfo)
  _G.C_Timer = savedCTimer
end
