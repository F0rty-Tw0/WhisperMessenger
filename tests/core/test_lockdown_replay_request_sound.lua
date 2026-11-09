local ReplayRuntime = require("tests.helpers.lockdown_replay_runtime")
local LockdownReplay = require("WhisperMessenger.Core.Bootstrap.LockdownReplay")

-- A lockdown replay batch plays at most one request sound, apart from the
-- batch's whisper alert.

local BELL = 5275

local function from(name)
  return { text = "held hello", name = name, guid = "Player-1-" .. name }
end

local function held(...)
  local lines, holds = {}, {}
  for lineID, name in ipairs({ ... }) do
    lines[lineID] = from(name)
    holds[lineID] = { "CHAT_MSG_WHISPER", lineID }
  end
  return lines, holds
end

local GLOBAL_NAMES = { "PlaySound", "PlaySoundFile", "IsGuildMember", "UnitInParty", "UnitInRaid" }

return function()
  local saved = {}
  for _, name in ipairs(GLOBAL_NAMES) do
    saved[name] = rawget(_G, name)
  end

  local bells

  local function probeFor(...)
    bells = 0
    rawset(_G, "PlaySound", function(soundId)
      if soundId == BELL then
        bells = bells + 1
      end
    end)
    rawset(_G, "PlaySoundFile", function() end)
    rawset(_G, "IsGuildMember", function()
      return false
    end)
    rawset(_G, "UnitInParty", function()
      return false
    end)
    rawset(_G, "UnitInRaid", function()
      return nil
    end)
    local probe = ReplayRuntime.Probe(held(...))
    probe.runtime.accountState.settings = {
      requestsInbox = true,
      playSoundOnRequest = true,
      requestSound = "bell",
      playSoundOnWhisper = true,
      notificationSound = "whisper",
    }
    probe.runtime.friendListApi = {
      IsFriend = function(guid)
        return guid == "Player-1-Friend-Realm"
      end,
    }
    probe.runtime.bnetApi = {
      GetGameAccountInfoByGUID = function()
        return nil
      end,
    }
    return probe
  end

  local function replay(probe)
    LockdownReplay.Kick(probe.runtime)
    ReplayRuntime.FireUntilDone(probe.runtime)
    probe.restore()
  end

  -- test_batch_with_requests_plays_one_request_sound
  do
    local probe = probeFor("Stranger1-Realm", "Stranger2-Realm")
    replay(probe)
    assert(probe.runtime.lockdownReplay.lastSummary.filed == 2, "setup: both whispers must file")
    assert(bells == 1, "a batch of requests plays one request sound, got " .. bells)
    assert(#probe.notified == 0, "requests never raise the whisper alert")
  end

  -- test_batch_without_requests_plays_no_request_sound
  do
    local probe = probeFor("Friend-Realm")
    replay(probe)
    assert(bells == 0, "no request in the batch: no request sound, got " .. bells)
    assert(#probe.notified == 1, "the friend's whisper alerts as before")
  end

  -- test_batch_with_whisper_and_request_plays_both
  do
    local probe = probeFor("Friend-Realm", "Stranger1-Realm")
    replay(probe)
    assert(bells == 1, "the request sound plays beside the whisper alert, got " .. bells)
    assert(#probe.notified == 1, "the friend's whisper still alerts")
  end

  for _, name in ipairs(GLOBAL_NAMES) do
    rawset(_G, name, saved[name])
  end
end
