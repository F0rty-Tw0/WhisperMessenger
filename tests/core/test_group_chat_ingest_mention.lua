local Store = require("WhisperMessenger.Model.ConversationStore")
local GroupChatIngest = require("WhisperMessenger.Core.Ingest.GroupChatIngest")

local GUILD_KEY = "guild::arthas-area52"

return function()
  local savedUnitName = _G.UnitName
  local savedGetGuildInfo = _G.GetGuildInfo
  rawset(_G, "UnitName", function()
    return "Arthas"
  end)
  _G.GetGuildInfo = nil

  local function makeState(activeKey)
    return {
      localProfileId = "arthas-area52",
      localPlayerGuid = "Player-1-SELF",
      store = Store.New({ maxMessagesPerConversation = 50 }),
      activeConversationKey = activeKey,
    }
  end

  local function guildLine(text, guid)
    return { text = text, playerName = "Jaina-Area52", lineID = 7, guid = guid or "Player-1-JAINA" }
  end

  -- test_group_line_naming_the_player_is_a_mention
  do
    local state = makeState()
    local handled, conversation, meta = GroupChatIngest.HandleEvent(state, "CHAT_MSG_GUILD", guildLine("arthas can you tank?"))
    conversation = assert(conversation, "conversation stored")
    assert(handled == true, "guild line handled")
    assert(conversation.messages[1].mention == true, "the stored message is flagged as a mention")
    assert(meta and meta.mention == true, "the caller is told a mention arrived")
    assert(conversation.hasUnreadMention == true, "the conversation shows an unread mention")
  end

  -- test_line_without_the_name_is_not_a_mention
  do
    local state = makeState()
    local _, conversation, meta = GroupChatIngest.HandleEvent(state, "CHAT_MSG_GUILD", guildLine("anyone for Arathi?"))
    conversation = assert(conversation, "conversation stored")
    assert(conversation.messages[1].mention == nil, "no mention flag")
    assert(meta == nil or meta.mention ~= true, "no mention reported")
    assert(conversation.hasUnreadMention == nil, "no unread mention")
  end

  -- test_own_message_is_never_a_mention
  do
    local state = makeState()
    local _, conversation, meta = GroupChatIngest.HandleEvent(state, "CHAT_MSG_GUILD", guildLine("Arthas here", "Player-1-SELF"))
    conversation = assert(conversation, "conversation stored")
    assert(conversation.messages[1].mention == nil, "own line is not a mention")
    assert(meta == nil or meta.mention ~= true, "own line reports no mention")
  end

  -- test_mention_in_open_conversation_is_already_read
  do
    local state = makeState(GUILD_KEY)
    local _, conversation, meta = GroupChatIngest.HandleEvent(state, "CHAT_MSG_GUILD", guildLine("Arthas!"))
    conversation = assert(conversation, "conversation stored")
    assert(meta and meta.mention == true, "still a mention (alerts still fire)")
    assert(conversation.hasUnreadMention == nil, "no @ marker for the conversation on screen")
  end

  -- test_mark_read_clears_the_unread_mention
  do
    local state = makeState()
    local _, conversation = GroupChatIngest.HandleEvent(state, "CHAT_MSG_GUILD", guildLine("Arthas?"))
    conversation = assert(conversation, "conversation stored")
    Store.MarkRead(state.store, GUILD_KEY)
    assert(conversation.hasUnreadMention == nil, "reading the conversation clears the @ marker")
  end

  -- test_community_and_bnet_group_mentions_are_detected
  do
    local state = makeState()
    local _, conversation, meta = GroupChatIngest.HandleEvent(state, "CHAT_MSG_COMMUNITIES_CHANNEL", {
      text = "ping Arthas",
      playerName = "Jaina",
      lineID = 9,
      guid = "Player-1-JAINA",
      clubId = 1,
      streamId = 2,
    })
    conversation = assert(conversation, "conversation stored")
    assert(meta and meta.mention == true and conversation.hasUnreadMention == true, "community mention detected")
  end

  rawset(_G, "UnitName", savedUnitName)
  _G.GetGuildInfo = savedGetGuildInfo
end
