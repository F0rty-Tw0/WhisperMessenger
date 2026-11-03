local Store = require("WhisperMessenger.Model.ConversationStore")
local Router = require("WhisperMessenger.Core.EventRouter")

-- A CraftScan customer whispers "found you via CraftScan", then their client
-- speaks on the CRAFT_SCAN addon prefix. That late message tags the whisper
-- and applies the Addon greetings setting to it.

local SENDER = "Customer-Realm"
local GUID = "Player-1-CUSTOMER"

local function makeState(settings)
  local clock = 1000
  local state = {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 10 }),
    availabilityByGUID = {},
    pendingOutgoing = {},
    accountState = { settings = settings or {} },
    now = function()
      return clock
    end,
  }
  state.advance = function(seconds)
    clock = clock + seconds
  end
  return state
end

local nextLineID = 500
local function whisper(state, text, extra)
  nextLineID = nextLineID + 1
  local payload = { text = text or "found you via CraftScan: [Item]", playerName = SENDER, lineID = nextLineID, guid = GUID }
  for key, value in pairs(extra or {}) do
    payload[key] = value
  end
  return Router.HandleEvent(state, "CHAT_MSG_WHISPER", payload)
end

local function craftScan(state, channel)
  return Router.HandleEvent(state, "CHAT_MSG_ADDON", {
    prefix = "CRAFT_SCAN",
    text = "^1^encoded",
    channel = channel or "WHISPER",
    playerName = SENDER,
  })
end

local function lastMessage(conversation)
  return conversation.messages[#conversation.messages]
end

local function test_late_message_tags_the_whisper()
  local state = makeState()
  local conversation = whisper(state)
  state.advance(1)
  local result = craftScan(state)
  assert(lastMessage(conversation).addonGreeting == "CraftScan", "customer whisper tagged late")
  assert(result == conversation and result.conversationKey ~= nil, "the conversation comes back so the window refreshes")
end

local function test_late_tag_needs_whisper_channel()
  local state = makeState()
  local conversation = whisper(state)
  for _, channel in ipairs({ "CHANNEL", "PARTY", "GUILD", "RAID" }) do
    craftScan(state, channel)
  end
  assert(lastMessage(conversation).addonGreeting == nil, "group CRAFT_SCAN traffic tags nothing")
end

local function test_whisper_older_than_window_untagged()
  local state = makeState()
  local conversation = whisper(state)
  state.advance(4)
  craftScan(state)
  assert(lastMessage(conversation).addonGreeting == nil, "a whisper older than 3 s is not tagged")
end

local function test_two_addon_messages_tag_one_whisper()
  local state = makeState()
  local conversation = whisper(state, "an older line")
  state.advance(1)
  whisper(state)
  craftScan(state)
  craftScan(state)
  assert(conversation.messages[2].addonGreeting == "CraftScan", "the newest whisper is tagged")
  assert(conversation.messages[1].addonGreeting == nil, "the second addon message does not tag the older whisper")
end

local function test_replayed_whisper_never_tagged()
  local state = makeState()
  local conversation = whisper(state, nil, { replayedAt = 1000 })
  craftScan(state)
  assert(lastMessage(conversation).addonGreeting == nil, "lockdown replay is never tagged")
end

local function test_hide_removes_the_new_conversation()
  local state = makeState({ addonGreetings = "hide" })
  local conversation = whisper(state)
  local key = conversation.conversationKey
  craftScan(state)
  assert(state.store.conversations[key] == nil, "the conversation the whisper opened is removed")
end

local function test_hide_removes_the_message_and_its_unread()
  local state = makeState({ addonGreetings = "hide" })
  local conversation = whisper(state, "earlier chat")
  state.advance(10)
  whisper(state)
  assert(conversation.unreadCount == 2, "both whispers counted unread first")
  craftScan(state)
  assert(state.store.conversations[conversation.conversationKey] == conversation, "an older conversation stays")
  assert(#conversation.messages == 1 and conversation.messages[1].text == "earlier chat", "only the customer whisper is removed")
  assert(conversation.unreadCount == 1, "unread drops with it")
  assert(conversation.lastPreview == "earlier chat", "the preview falls back to the earlier line")
  local earlier = conversation.messages[1]
  assert(conversation.lastIncomingPreview == "earlier chat", "the incoming preview falls back, got " .. tostring(conversation.lastIncomingPreview))
  assert(conversation.lastIncomingAt == earlier.sentAt and conversation.lastIncomingLineID == earlier.lineID, "last incoming time and line fall back")
  assert(conversation.lastActivityAt == earlier.sentAt, "last activity falls back to the earlier line")
end

local function test_hide_clears_incoming_fields_when_no_whisper_remains()
  local state = makeState({ addonGreetings = "hide" })
  local conversation = Router.HandleEvent(state, "CHAT_MSG_WHISPER_INFORM", { text = "my reply", playerName = SENDER, lineID = 400, guid = GUID })
  state.advance(10)
  whisper(state)
  craftScan(state)
  assert(state.store.conversations[conversation.conversationKey] == conversation, "the conversation with my line stays")
  assert(conversation.lastIncomingPreview == nil and conversation.lastIncomingAt == nil, "no incoming line is left to describe")
  assert(conversation.lastActivityAt == conversation.messages[1].sentAt, "last activity is my own line")
end

local function test_hide_while_open_leaves_unread_alone()
  local state = makeState({ addonGreetings = "hide" })
  local conversation = whisper(state, "earlier chat")
  assert(conversation.unreadCount == 1, "the earlier line came in while closed")
  state.activeConversationKey = conversation.conversationKey
  state.advance(10)
  whisper(state)
  assert(conversation.unreadCount == 1, "a whisper into the open conversation is not counted unread")
  craftScan(state)
  assert(#conversation.messages == 1, "the customer whisper is removed")
  assert(conversation.unreadCount == 1, "hiding it leaves unread alone, got " .. tostring(conversation.unreadCount))
end

local function test_hide_forgets_the_reply_target_it_removed()
  local state = makeState({ addonGreetings = "hide" })
  local conversation = whisper(state)
  state.lastIncomingWhisperKey = conversation.conversationKey
  craftScan(state)
  assert(state.lastIncomingWhisperKey == nil, "reply-to-last no longer points at the removed conversation")
end

local function test_hide_keeps_another_reply_target()
  local state = makeState({ addonGreetings = "hide" })
  whisper(state)
  state.lastIncomingWhisperKey = "wow::other"
  craftScan(state)
  assert(state.lastIncomingWhisperKey == "wow::other", "an unrelated reply target stays")
end

local function test_requests_mode_files_the_new_conversation()
  local state = makeState({ addonGreetings = "requests", requestsInbox = true })
  local conversation = whisper(state)
  craftScan(state)
  assert(conversation.request == true, "the conversation the whisper opened waits in Requests")
  assert(lastMessage(conversation).addonGreeting == "CraftScan", "still tagged")
end

local function test_requests_mode_leaves_an_existing_conversation()
  local state = makeState({ addonGreetings = "requests", requestsInbox = true })
  local conversation = whisper(state, "earlier chat")
  state.advance(10)
  whisper(state)
  craftScan(state)
  assert(conversation.request ~= true, "an existing conversation is not moved to Requests")
end

local function test_hidden_greeting_shields_the_older_whisper()
  local state = makeState({ addonGreetings = "hide" })
  local conversation = whisper(state, "an older line")
  state.advance(2)
  Router.HandleEvent(state, "CHAT_MSG_ADDON", { prefix = "robots.txt", text = "Q:CraftScan", channel = "WHISPER", playerName = SENDER })
  assert(whisper(state) == nil, "announced whisper hidden")
  craftScan(state)
  assert(state.store.conversations[conversation.conversationKey] == conversation, "the older whisper is not hidden in its place")
end

return function()
  test_hidden_greeting_shields_the_older_whisper()
  test_late_message_tags_the_whisper()
  test_late_tag_needs_whisper_channel()
  test_whisper_older_than_window_untagged()
  test_two_addon_messages_tag_one_whisper()
  test_replayed_whisper_never_tagged()
  test_hide_removes_the_new_conversation()
  test_hide_removes_the_message_and_its_unread()
  test_hide_clears_incoming_fields_when_no_whisper_remains()
  test_hide_while_open_leaves_unread_alone()
  test_hide_forgets_the_reply_target_it_removed()
  test_hide_keeps_another_reply_target()
  test_requests_mode_files_the_new_conversation()
  test_requests_mode_leaves_an_existing_conversation()
end
