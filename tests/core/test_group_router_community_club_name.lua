local Store = require("WhisperMessenger.Model.ConversationStore")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local ConversationSnapshot = require("WhisperMessenger.Model.ConversationSnapshot")

-- A community line records which community it came from, so rows can say
-- "Raid Group - General". A failing club lookup never drops the line.

local function communityLine(runtime)
  return EventBridge.RouteGroupEvent(runtime, "CHAT_MSG_COMMUNITIES_CHANNEL", "hello", "Jaina-Area52", "", "Raid Group: General", "", "", 0, 0, "General", 0, 7, "Player-1-JAINA")
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
  for _, conversation in pairs(runtime.store.conversations) do
    return conversation
  end
  return nil
end

return function()
  local savedClub = _G.C_Club
  local getInfoShouldRaise = false
  rawset(_G, "C_Club", {
    GetInfoFromLastCommunityChatLine = function()
      return { clubId = 11, streamId = 22, clubType = 1 }
    end,
    GetClubInfo = function(_clubId)
      if getInfoShouldRaise then
        error("club info unavailable")
      end
      return { name = "Raid Group" }
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
  end

  rawset(_G, "C_Club", savedClub)
end
