-- The replay starts on the signals that chat is readable again: any
-- restriction going Inactive, the M+ resume, and entering the world.
local FakeChatLines = require("tests.helpers.fake_chat_lines")
local ReplayRuntime = require("tests.helpers.lockdown_replay_runtime")
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")
local RestrictionState = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.RestrictionState")
local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")
local MythicSuspendController = require("WhisperMessenger.Core.Bootstrap.MythicSuspendController")
local ChatReplyState = require("WhisperMessenger.Util.ChatReplyState")

local TYPES, STATES = RestrictedActions.TYPES, RestrictedActions.STATES

local function readable()
  return { text = "held hello", name = "Arthas-Area52", guid = "Player-1-ABC" }
end

-- A Bootstrap over a real replay runtime holding one whisper, with the chat
-- lock read from a real restriction cache plus the faked chat API.
local function holdOne()
  local restore = FakeChatLines.Install({ [7] = readable() })
  local runtime = ReplayRuntime.New()
  runtime.restrictedActions = RestrictedActions.New()
  runtime.isChatLocked = function()
    return runtime.restrictedActions.isChatLocked()
  end
  ReplayRuntime.Hold(runtime, "CHAT_MSG_WHISPER", 7)
  return { runtime = runtime }, restore
end

local function setRestriction(Bootstrap, restrictionType, newState)
  return RestrictionState.handleAddonRestrictionStateChanged(Bootstrap, restrictionType, newState, {})
end

local function lockChat(Bootstrap)
  Bootstrap.runtime.restrictedActions.updateFromEvent(TYPES.Chat, STATES.Active)
end

local function enterWorld(Bootstrap, isMythic)
  return Presence.handlePlayerEnteringWorld(Bootstrap, {
    getContentDetector = function()
      return {
        IsMythicRestricted = function()
          return isMythic
        end,
        IsCompetitiveContent = function()
          return false
        end,
      }
    end,
    getPresenceCache = function()
      return nil
    end,
  })
end

return function()
  local savedSuspended = rawget(_G, "_wmSuspended")
  local savedRestricted = rawget(_G, "C_RestrictedActions")
  rawset(_G, "C_RestrictedActions", nil)

  -- test_type5_inactive_kicks_replay

  do
    local Bootstrap, restore = holdOne()
    lockChat(Bootstrap)
    assert(setRestriction(Bootstrap, TYPES.Chat, STATES.Inactive) == true, "the handler must still claim the event")
    assert(#FakeChatLines.ticks == 1, "a chat lock lifting must start the replay ticker")
    restore()
  end

  -- test_encounter_inactive_without_type5_kicks_replay

  do
    local Bootstrap, restore = holdOne()
    setRestriction(Bootstrap, TYPES.Encounter, STATES.Inactive)
    assert(#FakeChatLines.ticks == 1, "an encounter ending must start the replay ticker")
    restore()
  end

  -- test_pvp_inactive_without_type5_kicks_replay

  do
    local Bootstrap, restore = holdOne()
    setRestriction(Bootstrap, TYPES.PvPMatch, STATES.Inactive)
    assert(#FakeChatLines.ticks == 1, "a PvP match ending must start the replay ticker")
    restore()
  end

  -- test_restriction_active_does_not_kick

  do
    local Bootstrap, restore = holdOne()
    setRestriction(Bootstrap, TYPES.Encounter, STATES.Active)
    assert(#FakeChatLines.ticks == 0, "a restriction turning on must not start the replay ticker")
    restore()
  end

  -- test_mplus_completion_order_type5_then_resume

  do
    local Bootstrap, restore = holdOne()
    MythicSuspendController.Attach(Bootstrap.runtime, { Bootstrap = Bootstrap })
    lockChat(Bootstrap)
    rawset(_G, "_wmSuspended", true)
    setRestriction(Bootstrap, TYPES.Chat, STATES.Inactive)
    assert(#FakeChatLines.ticks == 0, "a lift while still suspended must start no ticker")
    Bootstrap.runtime.resume()
    assert(#FakeChatLines.ticks == 1, "resume after the lift must start the replay ticker")
    FakeChatLines.Fire()
    assert(Bootstrap.runtime.lockdownReplay.lastSummary.filed == 1, "the held whisper must file after resume")
    rawset(_G, "_wmSuspended", savedSuspended)
    restore()
  end

  -- test_mplus_completion_order_resume_then_type5

  do
    local Bootstrap, restore = holdOne()
    MythicSuspendController.Attach(Bootstrap.runtime, { Bootstrap = Bootstrap })
    lockChat(Bootstrap)
    rawset(_G, "_wmSuspended", true)
    Bootstrap.runtime.resume()
    assert(#FakeChatLines.ticks == 0, "resume while chat is still locked must start no ticker")
    setRestriction(Bootstrap, TYPES.Chat, STATES.Inactive)
    assert(#FakeChatLines.ticks == 1, "the chat lock lifting after resume must start the replay ticker")
    rawset(_G, "_wmSuspended", savedSuspended)
    restore()
  end

  -- test_pew_fall_through_kicks

  do
    local Bootstrap, restore = holdOne()
    lockChat(Bootstrap)
    assert(enterWorld(Bootstrap, false) == true, "the handler must still claim the event")
    assert(#FakeChatLines.ticks == 1, "entering the world with chat open must start the replay ticker")
    restore()
  end

  -- test_pew_entering_mythic_does_not_kick

  do
    local Bootstrap, restore = holdOne()
    local suspends = 0
    Bootstrap.runtime.suspend = function()
      suspends = suspends + 1
    end
    enterWorld(Bootstrap, true)
    assert(suspends == 1, "setup: entering Mythic must suspend")
    assert(#FakeChatLines.ticks == 0, "entering Mythic must not start the replay ticker")
    restore()
  end

  -- test_challenge_mode_inactive_still_scrubs_and_resumes

  do
    local Bootstrap, restore = holdOne()
    Bootstrap._inMythicContent = true
    local resumes, scrubs = 0, 0
    Bootstrap.runtime.resume = function()
      resumes = resumes + 1
    end
    local savedScrub = ChatReplyState.ScrubStaleWhisperReplyState
    rawset(ChatReplyState, "ScrubStaleWhisperReplyState", function()
      scrubs = scrubs + 1
    end)
    setRestriction(Bootstrap, TYPES.ChallengeMode, STATES.Inactive)
    rawset(ChatReplyState, "ScrubStaleWhisperReplyState", savedScrub)
    assert(resumes == 1, "a key ending must still resume, got " .. resumes)
    assert(scrubs == 1, "a key ending must still scrub the reply sticky, got " .. scrubs)
    assert(Bootstrap._inMythicContent == false, "a key ending must still clear the Mythic flag")
    restore()
  end

  -- test_challenge_mode_inactive_kicks_replay

  do
    local Bootstrap, restore = holdOne()
    setRestriction(Bootstrap, TYPES.ChallengeMode, STATES.Inactive)
    assert(#FakeChatLines.ticks == 1, "a key ending must start the replay ticker")
    restore()
  end

  rawset(_G, "_wmSuspended", savedSuspended)
  rawset(_G, "C_RestrictedActions", savedRestricted)
end
