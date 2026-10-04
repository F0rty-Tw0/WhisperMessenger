local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Router = require("WhisperMessenger.Core.EventRouter")
local Store = require("WhisperMessenger.Model.ConversationStore")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")

-- A long whisper end to end: what the sender puts on the wire, replayed into
-- a receiver in different orders. Both sides show one bubble when the
-- receiver gets the side messages; without them the parts stay separate.

local SENDER_KEY = "wow::WOW::thrall-nagrand"
local RECEIVER_KEY = "wow::WOW::arthas-area52"

local function longText()
  local list = {}
  for index = 1, 100 do
    list[index] = "word" .. string.format("%04d", index)
  end
  -- 100 words of 8 letters: 899 bytes, four 255-byte parts.
  return table.concat(list, " ")
end

local function newState(wire)
  return {
    localProfileId = "me",
    sendStatusByConversation = {},
    pendingOutgoing = {},
    availabilityByGUID = {},
    now = function()
      return 100
    end,
    chatApi = {
      SendChatMessage = function(text)
        wire[#wire + 1] = { kind = "whisper", text = text }
      end,
      RegisterAddonMessagePrefix = function()
        return true
      end,
      SendAddonMessage = function(_prefix, payload)
        wire[#wire + 1] = { kind = "addon", text = payload }
      end,
    },
    bnetApi = {},
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10, messageMaxAge = 86400, conversationMaxAge = 86400 }),
  }
end

-- Sends text and plays back the game's echoes; returns sender state and wire.
local function sendAndEcho(text)
  local wire = {}
  local sender = newState(wire)
  local sent = SendHandler.HandleSend(sender, {
    conversationKey = SENDER_KEY,
    target = "Thrall-Nagrand",
    displayName = "Thrall-Nagrand",
    channel = "WOW",
    text = text,
  }, function() end)
  assert(sent == true, "sent")
  for _, item in ipairs(wire) do
    if item.kind == "whisper" then
      Router.HandleEvent(sender, "CHAT_MSG_WHISPER_INFORM", { text = item.text, playerName = "Thrall-Nagrand", guid = "Player-2" })
    end
  end
  return sender, wire
end

local function deliver(receiver, item, lineID)
  if item.kind == "whisper" then
    Router.HandleEvent(receiver, "CHAT_MSG_WHISPER", { text = item.text, playerName = "Arthas-Area52", guid = "Player-1", lineID = lineID })
  else
    Router.HandleEvent(receiver, "CHAT_MSG_ADDON", { prefix = "WMRX", text = item.text, channel = "WHISPER", playerName = "Arthas-Area52" })
  end
end

-- order: wire indices in delivery order.
local function receive(wire, order)
  local receiver = newState({})
  for position, index in ipairs(order) do
    deliver(receiver, wire[index], position)
  end
  return receiver.store.conversations[RECEIVER_KEY]
end

return function()
  local text = longText()
  local sender, wire = sendAndEcho(text)
  -- wire: whispers 1-4, then identity (5) and manifest (6).
  assert(#wire == 6 and wire[5].kind == "addon" and wire[6].kind == "addon", "4 whispers + 2 side messages, got " .. #wire)

  -- test_sender_echoes_show_one_bubble
  do
    local messages = sender.store.conversations[SENDER_KEY].messages
    assert(#messages == 1, "sender shows one bubble, got " .. #messages)
    assert(messages[1].text == text and messages[1].direction == "out", "with the whole text")
    assert(sender.store.conversations[SENDER_KEY].lastPreview == text, "preview is the whole text")
  end

  -- test_receiver_merges_parts_and_side_messages_in_any_order
  do
    local orders = {
      { 1, 2, 3, 4, 5, 6 },
      { 5, 6, 1, 2, 3, 4 },
      { 2, 5, 1, 4, 6, 3 },
      { 4, 3, 6, 2, 1, 5 },
    }
    for _, order in ipairs(orders) do
      local conversation = receive(wire, order)
      local label = table.concat(order, ",")
      assert(#conversation.messages == 1, label .. ": one bubble, got " .. #conversation.messages)
      assert(conversation.messages[1].text == text, label .. ": whole text, got " .. conversation.messages[1].text)
      assert(conversation.unreadCount == 1, label .. ": one unread, got " .. conversation.unreadCount)
      assert(conversation.lastIncomingPreview == text, label .. ": preview is the whole text")
    end
  end

  -- test_receiver_without_the_manifest_shows_separate_parts
  do
    local conversation = receive(wire, { 1, 2, 3, 4, 5 })
    assert(#conversation.messages == 4, "four bubbles, got " .. #conversation.messages)
    assert(conversation.unreadCount == 4, "four unread")
  end

  -- test_reaction_to_the_merged_message_lands_on_the_sender_bubble
  do
    local receiverMessage = receive(wire, { 1, 2, 3, 4, 5, 6 }).messages[1]
    local fallback = Protocol.BuildFallback("heart", "set", receiverMessage.text)
    local operation = Protocol.EncodeReaction("set", "heart", receiverMessage.wireId, receiverMessage.text, fallback)
    Router.HandleEvent(sender, "CHAT_MSG_ADDON", { prefix = "WMRX", text = operation, channel = "WHISPER", playerName = "Thrall-Nagrand" })
    Router.HandleEvent(sender, "CHAT_MSG_WHISPER", { text = fallback, playerName = "Thrall-Nagrand", guid = "Player-2", lineID = 9 })
    local host = sender.store.conversations[SENDER_KEY].messages[1]
    assert(host.reaction and host.reaction.key == "heart", "reaction on the merged bubble")
  end

  -- test_single_part_send_is_unchanged
  do
    local shortSender, shortWire = sendAndEcho("hello there")
    assert(#shortWire == 2 and shortWire[2].text:sub(1, 4) == "1|I|", "one whisper + identity")
    local messages = shortSender.store.conversations[SENDER_KEY].messages
    assert(#messages == 1 and messages[1].text == "hello there" and messages[1].partCount == nil, "plain bubble")
    local conversation = receive(shortWire, { 1, 2 })
    assert(#conversation.messages == 1 and conversation.messages[1].wireId ~= nil, "receiver pairs as before")
  end
end
