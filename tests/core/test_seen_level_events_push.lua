require("tests.helpers.fake_ui")
local Identity = require("WhisperMessenger.Model.Identity")
local SeenLevel = require("WhisperMessenger.Model.SeenLevel")
local SeenLevelEvents = require("WhisperMessenger.Core.SeenLevelEvents")

local STUBBED = { "UnitIsPlayer", "UnitGUID", "UnitLevel", "UnitFullName", "IsInRaid", "GetNumGroupMembers", "Ambiguate", "_wmSuspended" }

local function fire(event, ...)
  local frame = SeenLevelEvents._frame
  frame:GetScript("OnEvent")(frame, event, ...)
end

-- One player per unit token: units[unit] = { guid, level, name, realm }.
local function stubUnits(units)
  rawset(_G, "UnitIsPlayer", function(unit)
    return units[unit] ~= nil
  end)
  rawset(_G, "UnitGUID", function(unit)
    return units[unit] and units[unit].guid
  end)
  rawset(_G, "UnitLevel", function(unit)
    return units[unit] and units[unit].level
  end)
  rawset(_G, "UnitFullName", function(unit)
    local u = units[unit]
    if u == nil then
      return nil
    end
    return u.name, u.realm
  end)
end

local function makeRuntime()
  local runtime = {
    localProfileId = "me",
    store = { conversations = {} },
    friendListApi = {},
    refreshed = {},
    windowRefreshes = 0,
  }
  runtime.scheduleIncomingRefresh = function(key)
    runtime.refreshed[#runtime.refreshed + 1] = key
  end
  runtime.refreshWindow = function()
    runtime.windowRefreshes = runtime.windowRefreshes + 1
  end
  return runtime
end

local function saveChat(runtime, nameKey, channel)
  local key = Identity.BuildConversationKey(runtime.localProfileId, "WOW::" .. nameKey)
  local conversation = { conversationKey = key, channel = channel or "WOW" }
  runtime.store.conversations[key] = conversation
  return key, conversation
end

return function()
  local saved = {}
  for _, name in ipairs(STUBBED) do
    saved[name] = _G[name]
  end
  local function reset()
    for _, name in ipairs(STUBBED) do
      rawset(_G, name, nil)
    end
    SeenLevelEvents._reset()
    SeenLevel._reset()
  end

  -- test_group_roster_records_each_party_member
  do
    reset()
    stubUnits({
      party1 = { guid = "P1", level = 10, name = "Alpha" },
      party2 = { guid = "P2", level = 20, name = "Beta" },
    })
    rawset(_G, "IsInRaid", function()
      return false
    end)
    rawset(_G, "GetNumGroupMembers", function()
      return 3
    end)
    SeenLevelEvents.Init(makeRuntime())
    fire("GROUP_ROSTER_UPDATE")
    assert(SeenLevel.Get("P1") == 10, "party1 should be recorded")
    assert(SeenLevel.Get("P2") == 20, "party2 should be recorded")
  end

  -- test_group_roster_in_raid_records_raid_units
  do
    reset()
    stubUnits({ raid2 = { guid = "R2", level = 30, name = "Gamma" } })
    rawset(_G, "IsInRaid", function()
      return true
    end)
    rawset(_G, "GetNumGroupMembers", function()
      return 2
    end)
    SeenLevelEvents.Init(makeRuntime())
    fire("GROUP_ROSTER_UPDATE")
    assert(SeenLevel.Get("R2") == 30, "raid2 should be recorded")
  end

  -- test_friend_list_records_only_online_friends
  do
    reset()
    local runtime = makeRuntime()
    local friends = {
      { connected = true, guid = "F1", name = "Online", level = 40 },
      { connected = false, guid = "F2", name = "Offline", level = 50 },
    }
    runtime.friendListApi = {
      GetNumFriends = function()
        return 2
      end,
      GetFriendInfoByIndex = function(i)
        return friends[i]
      end,
    }
    SeenLevelEvents.Init(runtime)
    fire("FRIENDLIST_UPDATE")
    assert(SeenLevel.Get("F1") == 40, "online friend should be recorded")
    assert(SeenLevel.Get("F2", "Offline") == nil, "offline friend should not be recorded")
  end

  -- test_same_realm_sighting_pushes_level_to_saved_chat
  do
    reset()
    stubUnits({ target = { guid = "G1", level = 75, name = "Firstmoon" } })
    local runtime = makeRuntime()
    local key, conversation = saveChat(runtime, "firstmoon")
    SeenLevelEvents.Init(runtime)
    fire("PLAYER_TARGET_CHANGED")
    assert(key == "wow::WOW::firstmoon", "unexpected key " .. key)
    assert(conversation.characterLevel == 75, "saved chat should get level 75")
    assert(#runtime.refreshed == 1 and runtime.refreshed[1] == key, "refresh should be scheduled once for the chat")
    assert(runtime.windowRefreshes == 0, "refreshWindow must never run")
  end

  -- test_cross_realm_sighting_pushes_to_realm_key
  do
    reset()
    stubUnits({ target = { guid = "G3", level = 60, name = "Bob", realm = "OtherRealm" } })
    local runtime = makeRuntime()
    local key, conversation = saveChat(runtime, "bob-otherrealm")
    SeenLevelEvents.Init(runtime)
    fire("PLAYER_TARGET_CHANGED")
    assert(key == "wow::WOW::bob-otherrealm", "unexpected key " .. key)
    assert(conversation.characterLevel == 60, "cross-realm chat should get level 60")
  end

  -- test_bnet_conversation_is_not_written
  do
    reset()
    stubUnits({ target = { guid = "G1", level = 75, name = "Firstmoon" } })
    local runtime = makeRuntime()
    local _, conversation = saveChat(runtime, "firstmoon", "BN")
    SeenLevelEvents.Init(runtime)
    fire("PLAYER_TARGET_CHANGED")
    assert(conversation.characterLevel == nil, "BN conversation should not get a level")
    assert(#runtime.refreshed == 0, "no refresh for a BN conversation")
  end

  -- test_sighting_at_saved_level_schedules_no_refresh
  do
    reset()
    stubUnits({ target = { guid = "G1", level = 75, name = "Firstmoon" } })
    local runtime = makeRuntime()
    local _, conversation = saveChat(runtime, "firstmoon")
    conversation.characterLevel = 75
    SeenLevelEvents.Init(runtime)
    fire("PLAYER_TARGET_CHANGED")
    assert(SeenLevel.Get(nil, "Firstmoon") == 75, "the sighting is still recorded")
    assert(#runtime.refreshed == 0, "an unchanged level should schedule no refresh")
  end

  -- test_init_rebinds_runtime_for_push
  do
    reset()
    stubUnits({ target = { guid = "G1", level = 75, name = "Firstmoon" } })
    SeenLevelEvents.Init(makeRuntime())
    local runtime = makeRuntime()
    local _, conversation = saveChat(runtime, "firstmoon")
    SeenLevelEvents.Init(runtime)
    fire("PLAYER_TARGET_CHANGED")
    assert(conversation.characterLevel == 75, "push should use the latest runtime")
  end

  for _, name in ipairs(STUBBED) do
    rawset(_G, name, saved[name])
  end
  SeenLevelEvents._reset()
  SeenLevel._reset()
end
