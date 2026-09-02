local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local ContentDetector = require("WhisperMessenger.Core.ContentDetector")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")

return function()
  local savedGetInstanceInfo = _G.GetInstanceInfo
  local savedCTimer = _G.C_Timer
  local savedHasMythicPlus = FlavorCompat.hasMythicPlus

  _G.C_Timer = {
    After = function(_delay, fn)
      fn()
    end,
  }

  local function makeDeps(extra)
    extra = extra or {}
    return {
      getContentDetector = function()
        return ContentDetector
      end,
      getPresenceCache = function()
        return nil
      end,
      getNumChatWindows = extra.getNumChatWindows,
      getEditBox = extra.getEditBox,
    }
  end

  -- test_player_entering_world_sets_competitive_in_pvp

  do
    rawset(_G, "GetInstanceInfo", function()
      return "Warsong Gulch", "pvp", 1
    end)

    local Bootstrap = { runtime = { suspend = function() end, resume = function() end } }
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(Bootstrap._inCompetitiveContent == true, "should set _inCompetitiveContent=true when entering battleground")
  end

  -- test_player_entering_world_sets_competitive_in_arena

  do
    rawset(_G, "GetInstanceInfo", function()
      return "Nagrand Arena", "arena", 1
    end)

    local Bootstrap = { runtime = { suspend = function() end, resume = function() end } }
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(Bootstrap._inCompetitiveContent == true, "should set _inCompetitiveContent=true when entering arena")
  end

  -- test_player_entering_world_clears_competitive_in_open_world

  do
    rawset(_G, "GetInstanceInfo", function()
      return "Eastern Kingdoms", "none", 0
    end)

    local Bootstrap = { _inCompetitiveContent = true, runtime = { suspend = function() end, resume = function() end } }
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(Bootstrap._inCompetitiveContent == false, "should clear _inCompetitiveContent when entering open world")
  end

  -- test_player_entering_world_tracks_mythic_separately
  -- Mythic+ sets _inMythicContent (not _inCompetitiveContent) so the hard
  -- lockdown is driven by MythicSuspendController / RestrictedActions and
  -- fires only when the key is actually started, not on mere zone entry.

  do
    FlavorCompat.hasMythicPlus = true

    rawset(_G, "GetInstanceInfo", function()
      return "Dungeon", "party", 8
    end)

    local Bootstrap = { runtime = { suspend = function() end, resume = function() end } }
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(Bootstrap._inMythicContent == true, "should set _inMythicContent=true for mythic keystone")
    assert(Bootstrap._inCompetitiveContent == false, "should NOT set _inCompetitiveContent for mythic keystone (mythic is separate)")
  end
  -- test_player_entering_world_ignores_mythic_keystone_without_mythic_plus
  do
    FlavorCompat.hasMythicPlus = false
    rawset(_G, "GetInstanceInfo", function()
      return "Dungeon", "party", 8
    end)

    local calls = { suspend = 0 }
    local Bootstrap = {
      _inMythicContent = false,
      runtime = {
        suspend = function()
          calls.suspend = calls.suspend + 1
        end,
        resume = function() end,
      },
    }
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(Bootstrap._inMythicContent == false, "should not set _inMythicContent for Mythic Keystone without Mythic+")
    assert(calls.suspend == 0, "should not suspend for Mythic Keystone without Mythic+")
  end

  -- test_zone_changed_clears_competitive_when_leaving_pvp

  do
    rawset(_G, "GetInstanceInfo", function()
      return "Orgrimmar", "none", 0
    end)

    local Bootstrap = { _inCompetitiveContent = true }
    LifecycleHandlers.Handle(Bootstrap, "ZONE_CHANGED_NEW_AREA", makeDeps())

    assert(Bootstrap._inCompetitiveContent == false, "should clear _inCompetitiveContent on zone change out of pvp")
  end

  -- test_legacy_boss_fight_start_keeps_messaging_active

  do
    local callbackCalled = false
    local syncCalled = false
    local runtime = {
      suspend = function() end,
      resume = function() end,
    }
    local Bootstrap = {
      _inEncounter = false,
      runtime = runtime,
      onCompetitiveStateChanged = function()
        callbackCalled = true
      end,
      syncChatFilters = function()
        syncCalled = true
      end,
    }

    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_START", makeDeps())

    assert(Bootstrap._inEncounter == false, "legacy non-restricted boss fights must keep messaging active")
    assert(runtime.messagingNotice == nil, "legacy non-restricted boss fights must not create a restriction notice")
    assert(callbackCalled == false, "encounter start must not emit competitive state changes")
    assert(syncCalled == false, "encounter start must not sync chat filters")
  end

  -- test_legacy_boss_fight_end_keeps_authoritative_restriction_state

  do
    local callbackCalled = false
    local syncCalled = false
    local runtime = {
      suspend = function() end,
      resume = function() end,
      messagingNotice = "authoritative restriction state",
    }
    local Bootstrap = {
      _inEncounter = true,
      runtime = runtime,
      onCompetitiveStateChanged = function()
        callbackCalled = true
      end,
      syncChatFilters = function()
        syncCalled = true
      end,
    }

    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_END", makeDeps())

    assert(Bootstrap._inEncounter == true, "encounter end must not clear authoritative restriction state")
    assert(runtime.messagingNotice == "authoritative restriction state", "encounter end must not clear an authoritative restriction notice")
    assert(callbackCalled == false, "encounter end must not emit competitive state changes")
    assert(syncCalled == false, "encounter end must not sync chat filters")
  end

  -- test_encounter_end_scrubs_default_chat_whisper_reply_state

  -- Raw encounter end always cleans stale Blizzard reply state; restriction
  -- state is owned separately by ADDON_RESTRICTION_STATE_CHANGED.

  do
    local attributes = {
      chatType = "WHISPER",
      stickyType = "WHISPER",
      tellTarget = "Jaina",
    }
    local editBox = {
      GetAttribute = function(self, key)
        return attributes[key]
      end,
      SetAttribute = function(self, key, value)
        attributes[key] = value
      end,
      GetText = function()
        return ""
      end,
    }
    local Bootstrap = {
      runtime = {
        localProfileId = "me",
        store = { conversations = {} },
        now = function()
          return 300
        end,
        suspend = function() end,
        resume = function() end,
      },
    }

    LifecycleHandlers.Handle(
      Bootstrap,
      "ENCOUNTER_END",
      makeDeps({
        getNumChatWindows = function()
          return 1
        end,
        getEditBox = function(index)
          if index == 1 then
            return editBox
          end
          return nil
        end,
      })
    )

    assert(attributes.tellTarget == nil, "encounter end must clear stale Blizzard tellTarget after boss-fight reply")
    assert(attributes.chatType == "SAY", "encounter end must restore stale whisper chatType to SAY, got " .. tostring(attributes.chatType))
    assert(attributes.stickyType == "SAY", "encounter end must restore stale whisper stickyType to SAY, got " .. tostring(attributes.stickyType))
    assert(Bootstrap.runtime.lastIncomingWhisperKey == "wow::WOW::jaina", "encounter end must capture default chat tellTarget as reply target")
    assert(Bootstrap.runtime.store.conversations["wow::WOW::jaina"] ~= nil, "encounter end must ensure a conversation for captured reply target")
    assert(
      Bootstrap.runtime.store.conversations["wow::WOW::jaina"].channel == "WOW",
      "captured encounter reply target must be a character whisper conversation"
    )
  end

  -- test_player_entering_world_calls_competitive_state_callback

  do
    local callbackValue = nil
    local Bootstrap = {
      runtime = { suspend = function() end, resume = function() end },
      onCompetitiveStateChanged = function(active)
        callbackValue = active
      end,
    }

    rawset(_G, "GetInstanceInfo", function()
      return "Warsong Gulch", "pvp", 1
    end)

    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(callbackValue == true, "should call onCompetitiveStateChanged=true when entering BG")
  end

  -- test_player_entering_world_sets_messaging_notice_in_bg

  do
    local runtime = { suspend = function() end, resume = function() end }
    local Bootstrap = { runtime = runtime }

    rawset(_G, "GetInstanceInfo", function()
      return "Warsong Gulch", "pvp", 1
    end)

    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(runtime.messagingNotice ~= nil, "should set runtime.messagingNotice when entering battleground")
  end

  -- test_player_entering_world_clears_messaging_notice_in_open_world

  do
    local runtime = { suspend = function() end, resume = function() end, messagingNotice = "paused" }
    local Bootstrap = { runtime = runtime }

    rawset(_G, "GetInstanceInfo", function()
      return "Orgrimmar", "none", 0
    end)

    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(runtime.messagingNotice == nil, "should clear runtime.messagingNotice when entering open world")
  end

  -- test_player_regen_enabled_scrubs_stale_whisper_reply_state

  do
    local attributes = {
      chatType = "WHISPER",
      stickyType = "WHISPER",
      tellTarget = "Jaina",
    }
    local editBox = {
      GetAttribute = function(self, key)
        return attributes[key]
      end,
      SetAttribute = function(self, key, value)
        attributes[key] = value
      end,
      GetText = function()
        return ""
      end,
    }
    local Bootstrap = {
      runtime = {
        localProfileId = "me",
        store = { conversations = {} },
        now = function()
          return 300
        end,
        suspend = function() end,
        resume = function() end,
      },
    }

    LifecycleHandlers.Handle(
      Bootstrap,
      "PLAYER_REGEN_ENABLED",
      makeDeps({
        getNumChatWindows = function()
          return 1
        end,
        getEditBox = function(index)
          if index == 1 then
            return editBox
          end
          return nil
        end,
      })
    )

    assert(attributes.tellTarget == nil, "combat end must clear stale Blizzard tellTarget so Enter does not re-open messenger post-combat")
    assert(attributes.chatType == "SAY", "combat end must restore stale whisper chatType to SAY, got " .. tostring(attributes.chatType))
    assert(attributes.stickyType == "SAY", "combat end must restore stale whisper stickyType to SAY, got " .. tostring(attributes.stickyType))
    assert(Bootstrap.runtime.lastIncomingWhisperKey == "wow::WOW::jaina", "combat end must capture stale reply target before clearing")
  end

  -- test_player_regen_enabled_keeps_unresolved_battle_net_reply_state
  do
    local attributes = {
      chatType = "BN_WHISPER",
      stickyType = "BN_WHISPER",
      tellTarget = 999,
    }
    local editBox = {
      GetAttribute = function(_, key)
        return attributes[key]
      end,
      SetAttribute = function(_, key, value)
        attributes[key] = value
      end,
      GetText = function()
        return ""
      end,
    }
    local Bootstrap = {
      runtime = {
        localProfileId = "me",
        store = { conversations = {} },
        suspend = function() end,
        resume = function() end,
      },
    }

    LifecycleHandlers.Handle(
      Bootstrap,
      "PLAYER_REGEN_ENABLED",
      makeDeps({
        getNumChatWindows = function()
          return 1
        end,
        getEditBox = function()
          return editBox
        end,
      })
    )

    assert(attributes.chatType == "BN_WHISPER", "combat end must not scrub an unresolved Battle.net reply")
    assert(attributes.stickyType == "BN_WHISPER", "combat end must preserve unresolved Battle.net sticky state")
    assert(attributes.tellTarget == 999, "combat end must preserve unresolved Battle.net target")
  end

  -- test_player_entering_world_does_not_start_duplicate_presence_timer_loops

  do
    rawset(_G, "GetInstanceInfo", function()
      return "Orgrimmar", "none", 0
    end)

    local scheduled = {}
    _G.C_Timer = {
      After = function(delay, fn)
        scheduled[#scheduled + 1] = { delay = delay, fn = fn }
      end,
    }

    local PresenceCache = {
      Rebuild = function() end,
      IsStale = function()
        return false
      end,
      GetTTL = function()
        return 30
      end,
    }

    local Bootstrap = { runtime = { suspend = function() end, resume = function() end } }
    local deps = {
      getContentDetector = function()
        return ContentDetector
      end,
      getPresenceCache = function()
        return PresenceCache
      end,
    }

    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", deps)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", deps)

    local timerLoopSchedules = 0
    for _, call in ipairs(scheduled) do
      if call.delay == 30 then
        timerLoopSchedules = timerLoopSchedules + 1
      end
    end

    assert(timerLoopSchedules == 1, "PLAYER_ENTERING_WORLD must not start duplicate presence timer loops")
  end
  rawset(_G, "GetInstanceInfo", savedGetInstanceInfo)
  FlavorCompat.hasMythicPlus = savedHasMythicPlus
  _G.C_Timer = savedCTimer
end
