local FriendList = require("tests.helpers.bnet_friend_list")
local World = require("tests.helpers.relationship_world")
local Relationship = require("WhisperMessenger.Model.Relationship")
local BNetResolver = require("WhisperMessenger.Transport.BNetResolver")

-- Relationship.Resolve looks up a Battle.net friend's current character on
-- every call; it hands runtime.bnetPassCache to the resolver so a refresh
-- pass does not walk the friend list once per contact.

local STATES = { "wow", "app", "offline", "offline", "offline", "offline", "offline" }

local function newRuntime()
  local runtime = World.New().runtime
  local api, calls = FriendList.NewApi(STATES)
  runtime.bnetApi = api
  return runtime, calls
end

local function resolveAll(runtime)
  local primaries = {}
  for id = 1, #STATES do
    local relationship = Relationship.Resolve(FriendList.Contact(id), runtime)
    primaries[id] = relationship and relationship.primary or "none"
  end
  return table.concat(primaries, ",")
end

return function()
  -- test_resolve_with_runtime_pass_cache_walks_the_friend_list_once

  do
    local runtime, calls = newRuntime()
    runtime.bnetPassCache = BNetResolver.NewPassCache()
    resolveAll(runtime)
    assert(calls.friendInfo <= #STATES, "one walk of " .. #STATES .. " friends expected, got " .. calls.friendInfo .. " lookups")
  end

  -- test_resolve_with_runtime_pass_cache_gives_the_same_relationships

  do
    local uncached = resolveAll((newRuntime()))
    local cachedRuntime = newRuntime()
    cachedRuntime.bnetPassCache = BNetResolver.NewPassCache()
    local cached = resolveAll(cachedRuntime)
    assert(uncached == "bnet,bnet,bnet,bnet,bnet,bnet,bnet", uncached)
    assert(cached == uncached, "cached relationships differ: " .. cached)
  end
end
