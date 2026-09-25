local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local Constants = require("WhisperMessenger.Core.Constants")
local Localization = require("WhisperMessenger.Locale.Localization")

-- Notify when online: a flagged friend's offline -> online change prints one
-- chat line and plays the notification sound (if sound is on). The first
-- observation after login/reload only records state.

local deps = {
  loadModule = function(name)
    return require(name)
  end,
  getContentDetector = function() end,
  getPresenceCache = function() end,
}

return function()
  Localization.Configure({ language = "enUS" })
  local lines, sounds = {}, 0
  rawset(_G, "DEFAULT_CHAT_FRAME", {
    AddMessage = function(_, text)
      lines[#lines + 1] = text
    end,
  })
  rawset(_G, "PlaySound", function()
    sounds = sounds + 1
  end)

  local friendOnline = false
  local jaina = { channel = "WOW", displayName = "Jaina-Realm", notifyOnline = true }
  local thrall = { channel = "WOW", displayName = "Thrall-Realm" }
  local anduin = { channel = "BN", displayName = "Anduin#1", bnetAccountID = 7, notifyOnline = true }
  local Bootstrap = {
    runtime = {
      accountState = { settings = { playSoundOnWhisper = true } },
      now = function()
        return 900
      end,
      store = { conversations = { ["wow::jaina"] = jaina, ["wow::thrall"] = thrall, ["bnet::anduin"] = anduin } },
      friendListApi = {
        GetFriendInfo = function(name)
          if name == "Thrall-Realm" then
            error("unflagged contacts must not be looked up")
          end
          return { connected = friendOnline }
        end,
      },
    },
  }

  -- test_events_are_registered
  local registered = {}
  for _, name in ipairs(Constants.LIFECYCLE_EVENT_NAMES) do
    registered[name] = true
  end
  assert(registered.FRIENDLIST_UPDATE and registered.BN_FRIEND_ACCOUNT_ONLINE and registered.BN_FRIEND_ACCOUNT_OFFLINE, "friend events registered")

  -- test_first_friend_list_update_only_records
  LifecycleHandlers.Handle(Bootstrap, "FRIENDLIST_UPDATE", deps)
  assert(#lines == 0 and sounds == 0, "login burst: no alert")

  -- test_character_friend_coming_online_alerts_once
  friendOnline = true
  LifecycleHandlers.Handle(Bootstrap, "FRIENDLIST_UPDATE", deps)
  assert(#lines == 1, "one chat line, got " .. #lines)
  assert(string.find(lines[1], "Jaina-Realm is now online.", 1, true), "names the friend: " .. lines[1])
  assert(string.find(lines[1], "WhisperMessenger", 1, true), "uses the addon chat prefix")
  assert(sounds == 1, "notification sound played")
  assert(jaina.lastSeenAt == 900, "seen online now")
  LifecycleHandlers.Handle(Bootstrap, "FRIENDLIST_UPDATE", deps)
  assert(#lines == 1, "no repeat while still online")

  -- test_bnet_friend_first_event_only_records
  LifecycleHandlers.Handle(Bootstrap, "BN_FRIEND_ACCOUNT_ONLINE", deps, 7)
  assert(#lines == 1, "first Battle.net observation: no alert")

  -- test_bnet_friend_offline_then_online_alerts
  LifecycleHandlers.Handle(Bootstrap, "BN_FRIEND_ACCOUNT_OFFLINE", deps, 7)
  LifecycleHandlers.Handle(Bootstrap, "BN_FRIEND_ACCOUNT_ONLINE", deps, 7)
  assert(#lines == 2 and string.find(lines[2], "Anduin#1 is now online.", 1, true), "Battle.net friend alert")
  assert(anduin.lastSeenAt == 900, "Battle.net online event stamps last seen")

  -- test_sound_setting_off_stays_quiet
  Bootstrap.runtime.accountState.settings.playSoundOnWhisper = false
  friendOnline = false
  LifecycleHandlers.Handle(Bootstrap, "FRIENDLIST_UPDATE", deps)
  friendOnline = true
  LifecycleHandlers.Handle(Bootstrap, "FRIENDLIST_UPDATE", deps)
  assert(#lines == 3, "chat line still printed")
  assert(sounds == 2, "no sound when the sound setting is off")

  -- test_unflagged_contact_never_alerts
  jaina.notifyOnline = nil
  friendOnline = false
  LifecycleHandlers.Handle(Bootstrap, "FRIENDLIST_UPDATE", deps)
  friendOnline = true
  LifecycleHandlers.Handle(Bootstrap, "FRIENDLIST_UPDATE", deps)
  assert(#lines == 3, "flag off: no alert")

  -- test_no_runtime_is_harmless
  LifecycleHandlers.Handle({}, "FRIENDLIST_UPDATE", deps)
  LifecycleHandlers.Handle({}, "BN_FRIEND_ACCOUNT_ONLINE", deps, 7)

  rawset(_G, "DEFAULT_CHAT_FRAME", nil)
  rawset(_G, "PlaySound", nil)
end
