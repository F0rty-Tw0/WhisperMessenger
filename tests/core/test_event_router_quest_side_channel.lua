-- Regression: CHAT_MSG_ADDON with prefix "WMQL" buffers the id+name pairs
-- per sender, and a subsequent CHAT_MSG_WHISPER from that sender has its
-- `[Name]` substring spliced into a real clickable hyperlink in the stored
-- message. The user-facing effect: even though Blizzard's chat protocol
-- strips `(id)` from outgoing Classic whispers, our addon-message side
-- channel restores the link for recipients running the addon.

local Store = require("WhisperMessenger.Model.ConversationStore")
local Queue = require("WhisperMessenger.Model.LockdownQueue")
local Router = require("WhisperMessenger.Core.EventRouter")

local function makeState()
  return {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 10 }),
    queue = Queue.New(),
    activeConversationKey = nil,
    availabilityByGUID = {},
    pendingOutgoing = {},
    questLinkInbox = {},
    now = function()
      return 1000
    end,
    isChatMessagingLocked = function()
      return false
    end,
  }
end

local function firstConversation(state)
  local _, conv = next(state.store.conversations)
  return conv
end

return function()
  -- 1. CHAT_MSG_ADDON with prefix "WMQL" + WHISPER channel buffers entries.
  do
    local state = makeState()
    Router.HandleEvent(state, "CHAT_MSG_ADDON", {
      prefix = "WMQL",
      text = "4641:Your Place In The World",
      channel = "WHISPER",
      playerName = "Thrall-Nagrand",
    })
    local inbox = state.questLinkInbox["Thrall-Nagrand"]
    assert(type(inbox) == "table" and #inbox == 1, "expected addon message buffered")
    assert(inbox[1].id == "4641", "id buffered")
    assert(inbox[1].name == "Your Place In The World", "name buffered")
  end

  -- 2. CHAT_MSG_ADDON for unknown prefix is ignored.
  do
    local state = makeState()
    Router.HandleEvent(state, "CHAT_MSG_ADDON", {
      prefix = "OTHER",
      text = "should not buffer",
      channel = "WHISPER",
      playerName = "Sender",
    })
    assert(state.questLinkInbox["Sender"] == nil, "no buffer for other prefix")
  end

  -- 3. CHAT_MSG_ADDON outside WHISPER channel is ignored (we don't want to
  -- splice quest links into party chat or guild chat by accident).
  do
    local state = makeState()
    Router.HandleEvent(state, "CHAT_MSG_ADDON", {
      prefix = "WMQL",
      text = "4641:Your Place In The World",
      channel = "PARTY",
      playerName = "Sender",
    })
    assert(state.questLinkInbox["Sender"] == nil, "WMQL on PARTY ignored")
  end

  -- 4. Side-channel splice: CHAT_MSG_ADDON buffers id, then a stripped
  -- CHAT_MSG_WHISPER from the same sender renders clickable in the bubble.
  do
    local state = makeState()
    Router.HandleEvent(state, "CHAT_MSG_ADDON", {
      prefix = "WMQL",
      text = "4641:Your Place In The World",
      channel = "WHISPER",
      playerName = "Thrall-Nagrand",
    })
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = "do [Your Place In The World] now",
      playerName = "Thrall-Nagrand",
      lineID = 501,
      guid = "Player-1-9001",
    })

    local conversation = firstConversation(state)
    assert(conversation ~= nil, "incoming conversation recorded")
    local message = conversation.messages[1]
    local expected = "do |cffffff00|Hquest:4641:0|h[Your Place In The World]|h|r now"
    assert(message.text == expected, "expected clickable splice, got: " .. tostring(message.text))
  end

  -- 5. Without a buffered addon message, an incoming `[Name]` chat with no
  -- id stays as-is — there's nothing to recover.
  do
    local state = makeState()
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = "do [Your Place In The World] now",
      playerName = "Thrall-Nagrand",
      lineID = 502,
      guid = "Player-1-9001",
    })
    local conversation = firstConversation(state)
    local message = conversation.messages[1]
    assert(message.text == "do [Your Place In The World] now", "no addon message -> text unchanged, got: " .. tostring(message.text))
  end

  -- 6. BN_CHAT_MSG_ADDON buffers ids+names keyed by `bn:<accountID>` so a
  -- following CHAT_MSG_BN_WHISPER from the same friend renders clickable.
  do
    local state = makeState()
    Router.HandleEvent(state, "BN_CHAT_MSG_ADDON", {
      prefix = "WMQL",
      text = "4641:Your Place In The World",
      bnetAccountID = 77,
    })
    local inbox = state.questLinkInbox["bn:77"]
    assert(type(inbox) == "table" and #inbox == 1, "expected BN addon message buffered")
    assert(inbox[1].id == "4641", "id buffered")
    assert(inbox[1].name == "Your Place In The World", "name buffered")

    Router.HandleEvent(state, "CHAT_MSG_BN_WHISPER", {
      text = "do [Your Place In The World] now",
      playerName = "Friend-Realm",
      lineID = 601,
      channel = "BN",
      bnetAccountID = 77,
      accountInfo = { battleTag = "Friend#1234" },
    })

    local conversation = firstConversation(state)
    assert(conversation ~= nil, "BN whisper conversation recorded")
    local message = conversation.messages[1]
    local expected = "do |cffffff00|Hquest:4641:0|h[Your Place In The World]|h|r now"
    assert(message.text == expected, "expected BN splice, got: " .. tostring(message.text))
  end

  -- 7. BN addon messages with non-WMQL prefix are ignored.
  do
    local state = makeState()
    Router.HandleEvent(state, "BN_CHAT_MSG_ADDON", {
      prefix = "OTHER",
      text = "should not buffer",
      bnetAccountID = 88,
    })
    assert(state.questLinkInbox["bn:88"] == nil, "no buffer for other prefix on BN")
  end
end
