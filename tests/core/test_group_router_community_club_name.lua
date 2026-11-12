local Store = require("WhisperMessenger.Model.ConversationStore")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local ConversationSnapshot = require("WhisperMessenger.Model.ConversationSnapshot")

-- A community line records which community it came from, so rows can say
-- "Raid Group - General". A failing club lookup never drops the line.

local function communityLine(runtime)
  return EventBridge.RouteGroupEvent(
    runtime,
    "CHAT_MSG_COMMUNITIES_CHANNEL",
    "hello",
    "Jaina-Area52",
    "",
    "Raid Group: General",
    "",
    "",
    0,
    0,
    "General",
    0,
    7,
    "Player-1-JAINA"
  )
end

local function newRuntime()
  return {
    localProfileId = "arthas-area52",
    localPlayerGuid = "Player-1-SELF",
    store = Store.New({ maxMessagesPerConversation = 50 }),
    accountState = { settings = {} },
  }
end

local function firstConversation(runtime)
  local _, conversation = next(runtime.store.conversations)
  return conversation
end

return function()
  local savedClub = _G.C_Club
  local getInfoShouldRaise = false
  local clubNameFromApi = "Raid Group"
  rawset(_G, "C_Club", {
    GetInfoFromLastCommunityChatLine = function()
      return { clubId = 11, streamId = 22, clubType = 1 }
    end,
    GetClubInfo = function(clubId)
      if getInfoShouldRaise then
        error("club info unavailable")
      end
      if clubId ~= 11 then
        return nil
      end
      return { name = clubNameFromApi }
    end,
  })

  -- test_club_name_stamped_on_conversation
  do
    local runtime = newRuntime()
    communityLine(runtime)
    local conversation = assert(firstConversation(runtime), "community line stored")
    assert(conversation.clubName == "Raid Group", "club name stamped, got " .. tostring(conversation.clubName))
    local snapshot = ConversationSnapshot.Build("k", conversation, {})
    assert(snapshot.clubName == "Raid Group", "snapshot carries the club name, got " .. tostring(snapshot.clubName))
  end

  -- test_club_info_error_leaves_no_name
  do
    getInfoShouldRaise = true
    local runtime = newRuntime()
    communityLine(runtime)
    local conversation = assert(firstConversation(runtime), "line still ingested when club info raises")
    assert(conversation.clubName == nil, "no club name when lookup raises")
    getInfoShouldRaise = false
  end

  -- test_failed_lookup_keeps_saved_club_name
  do
    local runtime = newRuntime()
    communityLine(runtime)
    getInfoShouldRaise = true
    communityLine(runtime)
    getInfoShouldRaise = false
    local conversation = assert(firstConversation(runtime), "community line stored")
    assert(conversation.clubName == "Raid Group", "saved club name kept, got " .. tostring(conversation.clubName))
  end

  -- test_secret_club_name_is_dropped
  do
    local savedIsSecret = _G.issecretvalue
    rawset(_G, "issecretvalue", function(value)
      return value == "Raid Group"
    end)
    local runtime = newRuntime()
    local ok, err = pcall(communityLine, runtime)
    rawset(_G, "issecretvalue", savedIsSecret)
    assert(ok, "secret club name must not raise: " .. tostring(err))
    local conversation = assert(firstConversation(runtime), "line still ingested with a secret club name")
    assert(conversation.clubName == nil, "secret club name not stored, got " .. tostring(conversation.clubName))
  end

  -- test_club_name_secret_check_runs_before_empty_check
  -- A secret raises on comparison in 12.0, so an empty name must still be
  -- asked about before it is compared. Other code may ask about other empty
  -- fields, so compare against a line whose club name is not empty.
  do
    local savedIsSecret = _G.issecretvalue
    local emptyAsks = 0
    rawset(_G, "issecretvalue", function(value)
      if value == "" then
        emptyAsks = emptyAsks + 1
      end
      return false
    end)
    communityLine(newRuntime())
    local asksWithName = emptyAsks
    emptyAsks = 0
    clubNameFromApi = ""
    communityLine(newRuntime())
    clubNameFromApi = "Raid Group"
    rawset(_G, "issecretvalue", savedIsSecret)
    assert(emptyAsks == asksWithName + 1, "an empty club name is checked for secrecy first, asks " .. emptyAsks .. " vs " .. asksWithName)
  end

  rawset(_G, "C_Club", savedClub)
end
