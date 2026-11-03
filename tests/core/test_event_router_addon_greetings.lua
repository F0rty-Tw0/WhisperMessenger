local Store = require("WhisperMessenger.Model.ConversationStore")
local Router = require("WhisperMessenger.Core.EventRouter")

-- A "Q:<AddonName>" addon message on robots.txt, then a whisper from the same
-- sender: the stored whisper carries addonGreeting = <AddonName>.

local SENDER = "Crafter-Realm"
local GUID = "Player-1-CRAFT"

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

local function announce(state, text, channel, sender)
  return Router.HandleEvent(state, "CHAT_MSG_ADDON", {
    prefix = "robots.txt",
    text = text or "Q:CraftScan",
    channel = channel or "WHISPER",
    playerName = sender or SENDER,
  })
end

local nextLineID = 100
local function whisper(state, text, extra)
  nextLineID = nextLineID + 1
  local payload = { text = text or "Hi! I can craft that.", playerName = SENDER, lineID = nextLineID, guid = GUID }
  for key, value in pairs(extra or {}) do
    payload[key] = value
  end
  return Router.HandleEvent(state, "CHAT_MSG_WHISPER", payload)
end

local function lastMessage(conversation)
  return conversation.messages[#conversation.messages]
end

local function test_announced_whisper_is_tagged()
  local state = makeState()
  announce(state)
  local conversation = whisper(state)
  assert(lastMessage(conversation).addonGreeting == "CraftScan", "whisper tagged with the announcing addon")
end

local function test_only_the_next_whisper_is_tagged()
  local state = makeState()
  announce(state)
  whisper(state)
  local conversation = whisper(state, "a human follow-up")
  assert(lastMessage(conversation).addonGreeting == nil, "follow-up whisper untagged")
end

local function test_untagged_without_announcement()
  local state = makeState()
  local conversation = whisper(state)
  assert(lastMessage(conversation).addonGreeting == nil, "plain whisper untagged")
end

local function test_announcement_on_other_channel_ignored()
  local state = makeState()
  announce(state, "Q:CraftScan", "PARTY")
  local conversation = whisper(state)
  assert(lastMessage(conversation).addonGreeting == nil, "party announcement does not tag whispers")
end

local function test_stale_announcement_ignored()
  local state = makeState()
  announce(state)
  state.advance(11)
  local conversation = whisper(state)
  assert(lastMessage(conversation).addonGreeting == nil, "announcement older than the window ignored")
end

local function test_hide_mode_keeps_greeting_out()
  local state = makeState({ addonGreetings = "hide" })
  announce(state)
  local result = whisper(state)
  assert(result == nil, "hidden greeting returns nothing")
  assert(next(state.store.conversations) == nil, "hidden greeting is not stored")
  local conversation = whisper(state, "a human follow-up")
  assert(conversation and #conversation.messages == 1, "the next whisper is stored as usual")
end

local function test_requests_mode_files_new_conversation_as_request()
  local state = makeState({ addonGreetings = "requests", requestsInbox = true })
  announce(state)
  local conversation = whisper(state)
  assert(conversation.request == true, "greeting opens the conversation as a request")
  assert(lastMessage(conversation).addonGreeting == "CraftScan", "still tagged")
end

local function test_requests_mode_leaves_existing_conversation()
  local state = makeState({ addonGreetings = "requests", requestsInbox = true })
  whisper(state, "earlier chat")
  announce(state)
  local conversation = whisper(state)
  assert(conversation.request ~= true, "an existing conversation is not moved to Requests")
end

local function test_requests_mode_without_inbox_shows()
  local state = makeState({ addonGreetings = "requests", requestsInbox = false })
  announce(state)
  local conversation = whisper(state)
  assert(conversation.request ~= true, "no request flag while the Requests inbox is off")
  assert(lastMessage(conversation).addonGreeting == "CraftScan", "greeting shows and is tagged")
end

local function test_replayed_whisper_untagged()
  local state = makeState({ addonGreetings = "hide" })
  announce(state)
  local conversation = whisper(state, nil, { replayedAt = 990 })
  assert(conversation and lastMessage(conversation).addonGreeting == nil, "lockdown replay is never tagged or hidden")
end

local function test_secret_sender_skipped()
  local state = makeState()
  local secret = setmetatable({}, {
    __tostring = function()
      return "secret"
    end,
  })
  local original = Router._isSecretString
  Router._isSecretString = function(value)
    return value == secret
  end
  local ok = pcall(announce, state, "Q:CraftScan", "WHISPER", secret)
  Router._isSecretString = original
  assert(ok, "secret sender must not error")
  assert(state.addonGreetingInbox == nil or next(state.addonGreetingInbox) == nil, "secret announcement not recorded")
end

return function()
  test_announced_whisper_is_tagged()
  test_only_the_next_whisper_is_tagged()
  test_untagged_without_announcement()
  test_announcement_on_other_channel_ignored()
  test_stale_announcement_ignored()
  test_hide_mode_keeps_greeting_out()
  test_requests_mode_files_new_conversation_as_request()
  test_requests_mode_leaves_existing_conversation()
  test_requests_mode_without_inbox_shows()
  test_replayed_whisper_untagged()
  test_secret_sender_skipped()
end
