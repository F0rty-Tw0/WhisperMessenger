local Store = require("WhisperMessenger.Model.ConversationStore")
local GroupChatIngest = require("WhisperMessenger.Core.Ingest.GroupChatIngest")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

local STUBBED = { "UnitName", "GetGuildInfo", "UnitTokenFromGUID", "UnitLevel" }

return function()
  local saved = {}
  for _, name in ipairs(STUBBED) do
    saved[name] = _G[name]
  end
  rawset(_G, "UnitName", function()
    return "Arthas"
  end)
  _G.GetGuildInfo = nil
  rawset(_G, "UnitTokenFromGUID", function(guid)
    if guid == "Player-1-JAINA" then
      return "party1"
    end
    return nil
  end)
  rawset(_G, "UnitLevel", function(unit)
    if unit == "party1" then
      return 20
    end
    return nil
  end)

  local function makeState()
    return {
      localProfileId = "arthas-area52",
      localPlayerGuid = "Player-1-SELF",
      store = Store.New({ maxMessagesPerConversation = 50 }),
    }
  end

  local function guildLine(text, guid)
    return { text = text, playerName = "Jaina-Area52", lineID = 7, guid = guid }
  end

  local function storedMessage(payload)
    local _, conversation = GroupChatIngest.HandleEvent(makeState(), "CHAT_MSG_GUILD", payload)
    conversation = assert(conversation, "conversation stored")
    return conversation.messages[1]
  end

  -- test_option_off_skips_the_level_lookup
  -- Off by default: no lookup cost on every line for a hidden feature.
  do
    DisplayName.Configure({ showPlayerLevels = false })
    local message = storedMessage(guildLine("anyone for Deadmines?", "Player-1-JAINA"))
    assert(message.senderLevel == nil, "expected no senderLevel with the option off, got " .. tostring(message.senderLevel))
  end

  DisplayName.Configure({ showPlayerLevels = true })

  -- test_incoming_line_freezes_sender_level
  do
    local message = storedMessage(guildLine("anyone for Deadmines?", "Player-1-JAINA"))
    assert(message.senderLevel == 20, "expected senderLevel 20, got " .. tostring(message.senderLevel))
  end

  -- test_outgoing_line_has_no_sender_level
  -- The player is in their own guild roster, so a level is known for them;
  -- their own lines still get none.
  do
    PresenceCache._reset()
    PresenceCache._initForTest({
      GetGuildClubId = function()
        return 1
      end,
      GetSubscribedClubs = function()
        return {}
      end,
      GetClubMembers = function()
        return { 1 }
      end,
      GetMemberInfo = function()
        return { guid = "Player-1-SELF", presence = 1, level = 80 }
      end,
    }, {
      now = function()
        return 100
      end,
    })
    local message = storedMessage(guildLine("on my way", "Player-1-SELF"))
    PresenceCache._reset()
    assert(message.direction == "out", "own line is outgoing")
    assert(message.senderLevel == nil, "outgoing line has no senderLevel, got " .. tostring(message.senderLevel))
  end

  -- test_incoming_line_without_guid_has_no_sender_level
  do
    local message = storedMessage(guildLine("hello"))
    assert(message.direction == "in", "line without guid is incoming")
    assert(message.senderLevel == nil, "line without guid has no senderLevel")
  end

  DisplayName.Configure({ showPlayerLevels = false })
  for _, name in ipairs(STUBBED) do
    rawset(_G, name, saved[name])
  end
end
