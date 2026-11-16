local FriendList = require("tests.helpers.bnet_friend_list")
local BNetStatus = require("WhisperMessenger.Model.ContactEnricher.BNetStatus")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")
local BNetResolver = require("WhisperMessenger.Transport.BNetResolver")

-- BNetStatus.Apply hands runtime.bnetPassCache to the resolver, so a pass
-- that sets one walks the friend list once for all its contacts.

local STATES = { "wow", "app", "offline", "offline", "offline", "offline", "offline" }

local function newRuntime(api)
  return { store = { conversations = {} }, bnetApi = api }
end

local function applyAll(runtime)
  local statuses = {}
  for id = 1, #STATES do
    local contact = FriendList.Contact(id)
    BNetStatus.Apply(contact, runtime)
    statuses[id] = contact.availability.status
  end
  return statuses
end

return function()
  PresenceCache._reset()
  PresenceCache._setCache({})

  -- test_apply_with_runtime_pass_cache_walks_the_friend_list_once

  do
    local api, calls = FriendList.NewApi(STATES)
    local runtime = newRuntime(api)
    runtime.bnetPassCache = BNetResolver.NewPassCache()
    applyAll(runtime)
    assert(calls.friendInfo <= #STATES, "one walk of " .. #STATES .. " friends expected, got " .. calls.friendInfo .. " lookups")
  end

  -- test_apply_with_runtime_pass_cache_gives_the_same_statuses

  do
    local uncached = applyAll(newRuntime(FriendList.NewApi(STATES)))
    local cachedRuntime = newRuntime(FriendList.NewApi(STATES))
    cachedRuntime.bnetPassCache = BNetResolver.NewPassCache()
    local cached = applyAll(cachedRuntime)
    assert(table.concat(uncached, ",") == "CanWhisper,BNetOnline,Offline,Offline,Offline,Offline,Offline", table.concat(uncached, ","))
    assert(table.concat(cached, ",") == table.concat(uncached, ","), "cached statuses differ: " .. table.concat(cached, ","))
  end

  -- test_apply_without_runtime_pass_cache_asks_the_game_each_time

  do
    local states = { "wow", "offline" }
    local api = FriendList.NewApi(states)
    local runtime = newRuntime(api)
    local contact = FriendList.Contact(2)
    BNetStatus.Apply(contact, runtime)
    states[2] = "wow"
    contact.availability = nil
    BNetStatus.Apply(contact, runtime)
    assert(contact.availability.status == "CanWhisper", "no pass cache: the friend coming online is seen")
  end
end
