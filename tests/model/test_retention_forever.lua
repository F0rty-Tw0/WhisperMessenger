local Retention = require("WhisperMessenger.Model.Retention")
local Store = require("WhisperMessenger.Model.ConversationStore")

local DAY = 86400
local HUNDRED_YEARS = 100 * 365 * DAY
-- A clock well past today and a message from the first day of Unix time:
-- the oldest history a real account could hold.
local NOW = 2000000000
local ANCIENT = 1

local function ancientConversation()
  return { messages = { { sentAt = ANCIENT, direction = "in", kind = "user", text = "hi" } }, lastActivityAt = ANCIENT, unreadCount = 0 }
end

local function storeWithMaxAge(maxAge)
  local state = Store.New({ messageMaxAge = maxAge, conversationMaxAge = maxAge }, function()
    return NOW
  end)
  state.conversations["k::old"] = ancientConversation()
  return state
end

return function()
  -- test_forever_is_a_plain_number_of_at_least_a_century
  do
    -- A number (not 0 or nil) keeps older addon versions, which treat the
    -- setting as a max age, from wiping history after a downgrade.
    assert(type(Retention.FOREVER_SECONDS) == "number", "FOREVER_SECONDS must be a number")
    assert(Retention.FOREVER_SECONDS >= HUNDRED_YEARS, "FOREVER_SECONDS must cover at least a century, got " .. tostring(Retention.FOREVER_SECONDS))
  end

  -- test_forever_never_expires_a_message
  do
    local messages = { { sentAt = ANCIENT } }
    Retention.ExpireMessages(messages, Retention.FOREVER_SECONDS, NOW)
    assert(#messages == 1, "forever keeps the oldest message")
  end

  -- test_forever_keeps_old_contact_and_messages_on_full_pass
  do
    local state = storeWithMaxAge(Retention.FOREVER_SECONDS)
    Store.ExpireAll(state, NOW)
    local kept = state.conversations["k::old"]
    assert(kept ~= nil, "forever keeps the oldest contact")
    assert(#kept.messages == 1, "forever keeps the oldest contact's messages")
  end

  -- test_forever_keeps_old_contact_on_append_sweep
  do
    local state = storeWithMaxAge(Retention.FOREVER_SECONDS)
    Store.AppendIncoming(state, "k::new", { sentAt = NOW, direction = "in", kind = "user", text = "hey" }, false)
    local kept = state.conversations["k::old"]
    assert(kept ~= nil and #kept.messages == 1, "append sweep keeps the oldest contact and its messages under forever")
  end

  -- test_ninety_days_still_expires_old_contact
  do
    local state = storeWithMaxAge(90 * DAY)
    Store.ExpireAll(state, NOW)
    assert(state.conversations["k::old"] == nil, "a finite retention still removes the oldest contact")
  end
end
