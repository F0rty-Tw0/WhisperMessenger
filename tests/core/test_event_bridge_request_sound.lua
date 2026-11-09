local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

-- Request sound, end to end through the live whisper route: a request plays
-- its own sound (never the whisper alert, never a flash) when the player opted in.

local BELL = 5275
local PING = 5274
local WHISPER = 3081

local function whisper(runtime, name, guid)
  EventBridge.RouteLiveEvent(
    runtime,
    nil,
    "CHAT_MSG_WHISPER",
    "hello",
    name or "Stranger-Realm",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    1,
    guid or "Player-1-ABC"
  )
end

local function onlyConversation(runtime)
  local _, conversation = next(runtime.store.conversations)
  return conversation
end

return function()
  local flashes, played, clock

  local function setup(settings)
    flashes, played, clock = 0, {}, 100
    rawset(_G, "FlashClientIcon", function()
      flashes = flashes + 1
    end)
    rawset(_G, "PlaySound", function(soundId)
      played[#played + 1] = soundId
    end)
    rawset(_G, "PlaySoundFile", function() end)
    rawset(_G, "InCombatLockdown", function()
      return false
    end)
    rawset(_G, "IsGuildMember", function()
      return false
    end)
    rawset(_G, "UnitInParty", function()
      return false
    end)
    rawset(_G, "UnitInRaid", function()
      return nil
    end)
    _G.C_Timer = { After = function() end }
    return {
      store = { conversations = {}, config = {} },
      localProfileId = "me",
      now = function()
        return clock
      end,
      availabilityByGUID = {},
      pendingOutgoing = {},
      friendListApi = {
        IsFriend = function()
          return false
        end,
      },
      bnetApi = {
        GetGameAccountInfoByGUID = function()
          return nil
        end,
      },
      accountState = { settings = settings },
    }
  end

  -- test_request_plays_request_sound_when_on
  do
    local runtime = setup({ requestsInbox = true, playSoundOnRequest = true, requestSound = "bell" })
    whisper(runtime)
    assert(onlyConversation(runtime).request == true, "stranger's whisper is a request")
    assert(#played == 1 and played[1] == BELL, "a request plays the picked request sound once")
  end

  -- test_request_silent_when_toggle_off
  do
    local runtime = setup({ requestsInbox = true, requestSound = "bell", playSoundOnWhisper = true })
    whisper(runtime)
    assert(#played == 0, "toggle off: a request stays silent")
  end

  -- test_muted_request_silent
  do
    local runtime = setup({ requestsInbox = true, playSoundOnRequest = true, requestSound = "bell" })
    whisper(runtime)
    onlyConversation(runtime).muted = true
    clock = clock + 3
    whisper(runtime)
    assert(#played == 1, "a muted request makes no sound")
  end

  -- test_request_sound_plays_with_whisper_sound_off
  do
    local runtime = setup({ requestsInbox = true, playSoundOnRequest = true, requestSound = "bell", playSoundOnWhisper = false })
    whisper(runtime)
    assert(#played == 1 and played[1] == BELL, "request sound is independent of the whisper sound toggle")
  end

  -- test_request_never_flashes_taskbar
  do
    local runtime = setup({ requestsInbox = true, playSoundOnRequest = true, requestSound = "bell", flashTaskbarOnWhisper = true })
    whisper(runtime)
    assert(#played == 1, "the request sound played")
    assert(flashes == 0, "a request never flashes the taskbar")
  end

  -- test_second_request_within_two_seconds_silent
  do
    local runtime = setup({ requestsInbox = true, playSoundOnRequest = true, requestSound = "bell" })
    whisper(runtime)
    clock = clock + 1
    whisper(runtime)
    assert(#played == 1, "a second whisper inside the throttle window stays silent")
  end

  -- test_request_without_pick_plays_ping
  do
    local runtime = setup({ requestsInbox = true, playSoundOnRequest = true })
    whisper(runtime)
    assert(#played == 1 and played[1] == PING, "no pick: the request sound defaults to ping")
  end

  -- test_stranger_with_inbox_off_gets_whisper_alert_not_request_sound
  do
    local runtime = setup({
      requestsInbox = false,
      playSoundOnRequest = true,
      requestSound = "bell",
      playSoundOnWhisper = true,
      notificationSound = "whisper",
    })
    whisper(runtime)
    assert(#played == 1 and played[1] == WHISPER, "inbox off: the stranger gets the normal whisper alert")
  end

  for _, name in ipairs({ "FlashClientIcon", "PlaySound", "PlaySoundFile", "InCombatLockdown", "IsGuildMember", "UnitInParty", "UnitInRaid" }) do
    rawset(_G, name, nil)
  end
  _G.C_Timer = nil
end
