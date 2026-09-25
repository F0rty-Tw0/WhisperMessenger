local MessageReplies = require("WhisperMessenger.Model.MessageReplies")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local LivePresence = require("WhisperMessenger.Model.LivePresence")

-- Reply to a message: the local quote (author + short snippet) and the WMRX
-- "reply link" that lets another WhisperMessenger user render the same quote.
return function()
  -- test_snippet_is_plain_and_short
  do
    local function snippetOf(text)
      return MessageReplies.BuildTarget({ direction = "in", text = text }).snippet
    end
    assert(snippetOf("hello") == "hello", "short text unchanged")
    local snippet = snippetOf(string.rep("a", 80))
    assert(snippet == string.rep("a", 60) .. "…", "capped at 60 characters with an ellipsis: " .. snippet)
    local linked = snippetOf("get |cffffff00|Hquest:471:0|h[Apprentice's Duties]|h|r now")
    assert(linked == "get [Apprentice's Duties] now", "escape codes stripped: " .. linked)
    assert(snippetOf(string.rep("é", 70)) == string.rep("é", 60) .. "…", "never splits a character")
    assert(snippetOf(nil) == "", "nil safe")
  end

  -- test_build_target_captures_author_and_identity
  do
    local incoming = MessageReplies.BuildTarget({ id = "7", wireId = "w7", direction = "in", playerName = "Jaina", text = "hi" })
    assert(incoming.id == "7" and incoming.wireId == "w7" and incoming.direction == "in", "identity kept")
    assert(incoming.author == "Jaina" and incoming.snippet == "hi", "author + snippet")
    local own = MessageReplies.BuildTarget({ id = "8", direction = "out", text = "mine", playerName = "Jaina" })
    assert(own.author == nil and own.direction == "out", "own message: author resolved as You at render time")
  end

  -- test_can_reply_only_to_whispers
  do
    local message = { kind = "user", direction = "in", text = "x" }
    assert(MessageReplies.CanReply("WOW", message) and MessageReplies.CanReply("BN", message), "character + Battle.net")
    assert(not MessageReplies.CanReply("PARTY", message), "never group chats")
    assert(not MessageReplies.CanReply("WOW", { kind = "system", direction = "in" }), "not system lines")
    assert(not MessageReplies.CanReply("WOW", { kind = "user", direction = "out", delivery = "queued" }), "not unsent messages")
  end

  -- test_find_prefers_wire_identity
  do
    local messages = {
      { id = "1", direction = "out", wireId = "a" },
      { id = "2", direction = "in", wireId = "a" },
      { id = "3", direction = "in" },
    }
    assert(MessageReplies.Find(messages, { wireId = "a", direction = "in" }) == 2, "wire id + direction")
    assert(MessageReplies.Find(messages, { id = "3", direction = "in" }) == 3, "falls back to the local id")
    assert(MessageReplies.Find(messages, { id = "9", direction = "in" }) == nil, "gone from history")
  end

  -- test_link_round_trip_flips_direction_for_the_receiver
  do
    local link = MessageReplies.EncodeLink("new1", { wireId = "old1", direction = "in" })
    assert(link == "1|Q|new1|old1|Y", "reply to their message: " .. tostring(link))
    local decoded = assert(MessageReplies.DecodeLink(link), "decodes")
    assert(decoded.wireId == "new1" and decoded.targetWireId == "old1", "ids")
    assert(decoded.targetDirection == "out", "their message is the receiver's own outgoing message")
    local mine = assert(MessageReplies.DecodeLink(MessageReplies.EncodeLink("new2", { wireId = "old2", direction = "out" })), "decodes")
    assert(mine.targetDirection == "in", "my own message is incoming for the receiver")
    assert(MessageReplies.EncodeLink("new3", { direction = "in" }) == nil, "no wire id on the target: no link")
    assert(MessageReplies.EncodeLink(nil, { wireId = "x", direction = "in" }) == nil, "no own wire id: no link")
    assert(#MessageReplies.EncodeLink(string.rep("a", 32), { wireId = string.rep("b", 32), direction = "in" }) <= 255, "fits 255 bytes")
    assert(MessageReplies.DecodeLink("1|Q|a|b|Z") == nil and MessageReplies.DecodeLink("1|Q|a|b") == nil, "malformed rejected")
  end

  -- test_older_clients_ignore_the_reply_link
  -- Older WhisperMessenger versions run exactly these two decoders on every
  -- WMRX whisper payload and drop it silently when both return nil (no peer
  -- flag, no print, no error).
  do
    local link = MessageReplies.EncodeLink("new1", { wireId = "old1", direction = "in" })
    assert(Protocol.Decode(link) == nil, "reaction/identity decoder ignores the reply link")
    assert(LivePresence.Decode(link) == nil, "presence decoder ignores the reply link")
  end

  -- test_apply_link_attaches_the_quote
  do
    local state = {
      store = {
        conversations = {
          k = {
            messages = {
              { id = "1", direction = "out", wireId = "old1", text = "are you coming?" },
              { id = "2", direction = "in", wireId = "new1", text = "yes", playerName = "Jaina" },
            },
          },
        },
      },
    }
    assert(MessageReplies.ApplyLink(state, "k", MessageReplies.DecodeLink("1|Q|new1|old1|Y"), 10) == true, "applied")
    local reply = state.store.conversations.k.messages[2].replyTo
    assert(reply and reply.wireId == "old1" and reply.direction == "out", "points at my message")
    assert(reply.snippet == "are you coming?", "snippet from local history")
  end

  -- test_link_before_the_whisper_is_staged_then_claimed
  do
    local state =
      { store = { conversations = { k = { messages = { { id = "1", direction = "in", wireId = "old1", text = "ping", playerName = "Jaina" } } } } } }
    local link = MessageReplies.DecodeLink("1|Q|new1|old1|M")
    assert(MessageReplies.ApplyLink(state, "k", link, 10) == false, "whisper not here yet: staged")
    local arriving = { id = "2", direction = "in", wireId = "new1", text = "pong" }
    assert(MessageReplies.ClaimStaged(state, "k", arriving, 12) == true, "claimed when the whisper gets its identity")
    assert(arriving.replyTo and arriving.replyTo.author == "Jaina", "quote attached")
    assert(MessageReplies.ClaimStaged(state, "k", { direction = "in", wireId = "new1" }, 13) == false, "claimed once")
  end

  -- test_stale_staged_links_expire
  do
    local state = { store = { conversations = { k = { messages = { { direction = "in", wireId = "old1", text = "x" } } } } } }
    MessageReplies.ApplyLink(state, "k", MessageReplies.DecodeLink("1|Q|new1|old1|M"), 10)
    assert(MessageReplies.ClaimStaged(state, "k", { direction = "in", wireId = "new1" }, 500) == false, "expired")
  end
end
