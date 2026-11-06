local GroupChatService = require("WhisperMessenger.Core.GroupChat.GroupChatService")
local GroupChatEnv = require("tests.helpers.group_chat_env")
local IgnoreList = require("WhisperMessenger.Model.Filters.IgnoreList")

local GROUP_ID = "abcd1234"
local KEY = "wmgroup::" .. GROUP_ID

local function newService(env)
  return GroupChatService.Create({ runtime = env.runtime, timer = env.timer })
end

local function deliver(env, service, sender, body)
  local conversation, meta
  for _, payload in ipairs(env.packets(sender, body)) do
    conversation, meta = service.HandleAddonMessage(payload)
  end
  return conversation, meta
end

local function lastMessage(env)
  local messages = env.runtime.store.conversations[KEY].messages
  return messages[#messages]
end

return function()
  -- test_roster_adds_the_player_to_a_new_group
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    local conversation = deliver(env, service, "Anna-Kazzak", "R~" .. GROUP_ID .. "~Raid night~Anna-Kazzak,Me-Kazzak,Bela-Ragnaros")
    assert(conversation and conversation.conversationKey == KEY, "the group's conversation is returned")
    local group = service.registry[GROUP_ID]
    assert(group.name == "Raid night" and #group.members == 2, "group stored without self")
    assert(conversation.title == "Raid night")
    assert(lastMessage(env).text == "Anna added you to the group chat.", lastMessage(env).text)
    env.restore()
  end

  -- test_message_is_stored_as_an_incoming_line_and_may_alert
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    deliver(env, service, "Anna-Kazzak", "R~" .. GROUP_ID .. "~G~Anna-Kazzak,Me-Kazzak")
    local conversation, meta = deliver(env, service, "Anna-Kazzak", "M~" .. GROUP_ID .. "~hi |TInterface\\X:99|t" .. string.rep("!", 260))
    assert(meta and meta.groupChatMessage == true, "a chat line may alert")
    local message = lastMessage(env)
    assert(message.direction == "in" and message.playerName == "Anna-Kazzak", "sender kept")
    assert(message.text == "hi " .. string.rep("!", 260), "text cleaned and reassembled")
    assert(conversation.unreadCount == 1, "counts unread")
    env.restore()
  end

  -- test_message_naming_the_player_is_a_mention
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    deliver(env, service, "Anna-Kazzak", "M~" .. GROUP_ID .. "~hey Me, ready?")
    assert(lastMessage(env).mention == true)
    env.restore()
  end

  -- test_message_for_an_unknown_group_creates_it_and_asks_for_the_roster
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    deliver(env, service, "Anna-Kazzak", "M~" .. GROUP_ID .. "~hello")
    local group = service.registry[GROUP_ID]
    assert(group and #group.members == 1 and group.members[1] == "Anna-Kazzak", "placeholder group with the sender")
    assert(env.bodiesTo("Anna-Kazzak")[1] == "Q~" .. GROUP_ID, "asks for the member list")
    env.restore()
  end

  -- test_query_from_a_member_is_answered_with_the_roster
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    deliver(env, service, "Anna-Kazzak", "R~" .. GROUP_ID .. "~G~Anna-Kazzak,Me-Kazzak")
    env.sent = {}
    deliver(env, service, "Anna-Kazzak", "Q~" .. GROUP_ID)
    assert(env.bodiesTo("Anna-Kazzak")[1] == "R~" .. GROUP_ID .. "~G~Me-Kazzak,Anna-Kazzak")
    env.sent = {}
    deliver(env, service, "Stranger-Kazzak", "Q~" .. GROUP_ID)
    assert(#env.sent == 0, "strangers get no member list")
    env.restore()
  end

  -- test_roster_update_renames_and_announces_new_members
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    deliver(env, service, "Anna-Kazzak", "R~" .. GROUP_ID .. "~G~Anna-Kazzak,Me-Kazzak")
    deliver(env, service, "Anna-Kazzak", "R~" .. GROUP_ID .. "~New name~Anna-Kazzak,Me-Kazzak,Bela-Kazzak")
    local messages = env.runtime.store.conversations[KEY].messages
    assert(messages[#messages - 1].text == "Anna named the group New name.", messages[#messages - 1].text)
    assert(messages[#messages].text == "Anna added Bela.", messages[#messages].text)
    -- A stale list never removes anyone.
    deliver(env, service, "Bela-Kazzak", "R~" .. GROUP_ID .. "~New name~Bela-Kazzak,Me-Kazzak")
    assert(#service.registry[GROUP_ID].members == 2)
    env.restore()
  end

  -- test_leave_removes_the_sender
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    deliver(env, service, "Anna-Kazzak", "R~" .. GROUP_ID .. "~G~Anna-Kazzak,Me-Kazzak,Bela-Kazzak")
    deliver(env, service, "Bela-Kazzak", "L~" .. GROUP_ID)
    assert(#service.registry[GROUP_ID].members == 1)
    assert(lastMessage(env).text == "Bela left the group chat.")
    env.restore()
  end

  -- test_left_group_answers_lines_with_leave_and_rejoins_on_invite
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    deliver(env, service, "Anna-Kazzak", "R~" .. GROUP_ID .. "~G~Anna-Kazzak,Me-Kazzak")
    service.Leave(GROUP_ID)
    env.sent = {}
    local conversation = deliver(env, service, "Anna-Kazzak", "M~" .. GROUP_ID .. "~still there?")
    assert(conversation == nil, "a left group stores nothing")
    assert(env.bodiesTo("Anna-Kazzak")[1] == "L~" .. GROUP_ID, "the sender is told again")
    deliver(env, service, "Anna-Kazzak", "R~" .. GROUP_ID .. "~G~Anna-Kazzak,Me-Kazzak")
    assert(service.registry[GROUP_ID].left == nil, "a new invite rejoins")
    env.restore()
  end

  -- test_blocked_players_and_other_prefixes_are_ignored
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    IgnoreList.Add(env.accountState.filters, "Anna-Kazzak", { now = env.clock })
    assert(deliver(env, service, "Anna-Kazzak", "R~" .. GROUP_ID .. "~G~Anna-Kazzak,Me-Kazzak") == nil, "blocked sender dropped")
    assert(service.registry[GROUP_ID] == nil)
    assert(service.HandleAddonMessage({ prefix = "WMRX", text = "1aaaa11x", channel = "WHISPER", playerName = "Bela-Kazzak" }) == nil)
    assert(service.HandleAddonMessage({ prefix = "WMGC", text = "1aaaa11x", channel = "GUILD", playerName = "Bela-Kazzak" }) == nil)
    assert(deliver(env, service, "Me-Kazzak", "M~" .. GROUP_ID .. "~echo") == nil, "own packets are ignored")
    env.restore()
  end

  -- test_a_packet_clears_the_offline_skip
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    local key = service.Create("Anna")
    service.HandleSystemMessage("No player named 'Anna' is currently playing.")
    assert(service.outbox.IsSkipped("Anna-Kazzak"))
    local group = service.FindByConversationKey(key)
    deliver(env, service, "Anna-Kazzak", "Q~" .. group.id)
    assert(not service.outbox.IsSkipped("Anna-Kazzak"), "hearing from them means they are online")
    env.restore()
  end
end
