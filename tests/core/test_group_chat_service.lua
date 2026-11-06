local GroupChatService = require("WhisperMessenger.Core.GroupChat.GroupChatService")
local GroupChats = require("WhisperMessenger.Model.GroupChats")
local GroupChatEnv = require("tests.helpers.group_chat_env")

local function newService(env)
  local next = 0
  return GroupChatService.Create({
    runtime = env.runtime,
    timer = env.timer,
    random = function(n)
      next = next % n + 1
      return next
    end,
  })
end

local function lastMessage(conversation)
  return conversation.messages[#conversation.messages]
end

return function()
  -- test_create_stores_the_group_and_invites_every_member
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    local key = service.Create("Anna, Bela-Ragnaros, Me")
    assert(type(key) == "string" and string.find(key, "wmgroup::", 1, true) == 1, "returns the conversation key")
    local group = service.FindByConversationKey(key)
    assert(group and #group.members == 2, "self is not a member of the list")
    assert(group.name == "Anna, Bela", "named after the members, got " .. tostring(group.name))
    local conversation = env.runtime.store.conversations[key]
    assert(conversation.channel == "WM_GROUP" and conversation.title == "Anna, Bela", "conversation carries the group")
    assert(conversation.memberSummary == "Anna, Bela-Ragnaros", tostring(conversation.memberSummary))
    assert(lastMessage(conversation).kind == "system", "a notice opens the chat")
    assert(conversation.unreadCount == 0, "own notices are never unread")
    local bodies = env.bodiesTo("Anna-Kazzak")
    assert(#bodies == 1 and bodies[1] == "R~" .. group.id .. "~Anna, Bela~Me-Kazzak,Anna-Kazzak,Bela-Ragnaros", tostring(bodies[1]))
    assert(#env.bodiesTo("Bela-Ragnaros") == 1, "every member gets the roster")
    env.restore()
  end

  -- test_create_needs_a_name
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    local key, reason = service.Create(" , Me ")
    assert(key == nil and reason == "Enter at least one player name.", tostring(reason))
    assert(next(service.registry) == nil, "nothing stored")
    env.restore()
  end

  -- test_create_is_refused_while_paused
  do
    local env = GroupChatEnv.New()
    env.runtime.isCompetitiveContent = function()
      return true
    end
    local service = newService(env)
    local key, reason = service.Create("Anna")
    assert(key == nil and reason == "Group chats are paused here.")
    env.restore()
  end

  -- test_send_fans_out_and_appends_the_outgoing_line
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    local key = service.Create("Anna, Bela")
    local group = service.FindByConversationKey(key)
    env.sent = {}
    assert(service.Send(key, "hello all") == true)
    assert(env.bodiesTo("Anna-Kazzak")[1] == "M~" .. group.id .. "~hello all")
    assert(env.bodiesTo("Bela-Kazzak")[1] == "M~" .. group.id .. "~hello all")
    local message = lastMessage(env.runtime.store.conversations[key])
    assert(message.direction == "out" and message.text == "hello all", "outgoing line stored")
    assert(message.senderName == "Me" and message.senderClassTag == "MAGE", "sender frozen like party chat")
    assert(message.channel == "WM_GROUP")
    env.restore()
  end

  -- test_send_refuses_unknown_left_and_paused_chats
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    assert(service.Send("wmgroup::zzzzzzzz", "hi") == false, "unknown group")
    local key = service.Create("Anna")
    assert(service.Send(key, "") == false, "empty text")
    service.Leave(service.FindByConversationKey(key).id)
    assert(service.Send(key, "hi") == false, "left group")
    local key2 = service.Create("Bela")
    env.runtime.isCompetitiveContent = function()
      return true
    end
    assert(service.Send(key2, "hi") == false, "paused")
    env.restore()
  end

  -- test_notice_explains_why_sending_is_off
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    local key = service.Create("Anna")
    local group = service.FindByConversationKey(key)
    assert(service.Notice(key) == nil, "a live group can send")
    assert(service.Notice("wmgroup::zzzzzzzz") == "Group chat not found.")
    GroupChats.RemoveMember(group, "Anna-Kazzak")
    assert(service.Notice(key) == "Nobody else is in this group chat.")
    group.left = true
    assert(service.Notice(key) == "You left this group chat.")
    env.restore()
  end

  -- test_add_members_announces_and_sends_the_new_roster_to_everyone
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    local key = service.Create("Anna")
    local group = service.FindByConversationKey(key)
    env.sent = {}
    assert(service.AddMembers(group.id, "Bela, anna") == 1, "only the new name is added")
    assert(#env.bodiesTo("Bela-Kazzak") == 1, "the new member is invited")
    assert(#env.bodiesTo("Anna-Kazzak") == 1, "old members learn the new list")
    assert(lastMessage(env.runtime.store.conversations[key]).text == "You added Bela.")
    local count, reason = service.AddMembers(group.id, "anna")
    assert(count == nil and reason == "Enter at least one player name.")
    env.restore()
  end

  -- test_rename_updates_the_title_and_tells_members
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    local key = service.Create("Anna")
    local group = service.FindByConversationKey(key)
    env.sent = {}
    assert(service.Rename(group.id, "  Raid night ") == true)
    assert(env.runtime.store.conversations[key].title == "Raid night")
    assert(string.find(env.bodiesTo("Anna-Kazzak")[1], "~Raid night~", 1, true), "roster carries the new name")
    assert(service.Rename(group.id, "Raid night") == false, "same name is no change")
    assert(service.Rename(group.id, "   ") == false, "blank name refused")
    env.restore()
  end

  -- test_leave_tells_members_and_closes_the_chat
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    local key = service.Create("Anna")
    local group = service.FindByConversationKey(key)
    env.sent = {}
    assert(service.Leave(group.id) == true)
    assert(env.bodiesTo("Anna-Kazzak")[1] == "L~" .. group.id)
    assert(group.left == true and env.runtime.store.conversations[key].leftGroup == true, "chat is read-only now")
    assert(service.Leave(group.id) == false, "leaving twice does nothing")
    env.restore()
  end

  -- test_ensure_conversations_brings_back_removed_rows
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    local key = service.Create("Anna")
    env.runtime.store.conversations[key] = nil
    service.EnsureConversations()
    local conversation = env.runtime.store.conversations[key]
    assert(conversation and conversation.channel == "WM_GROUP" and conversation.title == "Anna", "row restored from the group")
    env.restore()
  end

  -- test_system_message_for_an_offline_member_is_claimed
  do
    local env = GroupChatEnv.New()
    local service = newService(env)
    service.Create("Anna")
    assert(service.ExpectsSystemMessage())
    assert(service.HandleSystemMessage("No player named 'Anna' is currently playing.") == true)
    assert(service.HandleSystemMessage("You are now AFK.") == false)
    env.restore()
  end
end
