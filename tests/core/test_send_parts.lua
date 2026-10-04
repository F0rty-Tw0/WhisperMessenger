local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local QueuedSends = require("WhisperMessenger.Core.Bootstrap.QueuedSends")
local Store = require("WhisperMessenger.Model.ConversationStore")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")

-- A whisper longer than one chat message goes out as several whispers that
-- share one wire id: one pending entry per part, the identity side message
-- for part 1 and one manifest side message for the rest.

local KEY = "me::WOW::thrall-nagrand"
local WORD = "abcdefghi"

-- words * 10 - 1 bytes; 25 words fill one 255-byte part.
local function words(count)
  local list = {}
  for index = 1, count do
    list[index] = WORD
  end
  return table.concat(list, " ")
end

local function newRuntime(whispers, addonMessages)
  return {
    sendStatusByConversation = {},
    pendingOutgoing = {},
    availabilityByGUID = {},
    now = function()
      return 100
    end,
    localProfileId = "me",
    chatApi = {
      SendChatMessage = function(text, _chatType, _languageID, target)
        whispers[#whispers + 1] = { text = text, target = target }
      end,
      RegisterAddonMessagePrefix = function()
        return true
      end,
      SendAddonMessage = function(prefix, payload, _channel, target)
        addonMessages[#addonMessages + 1] = { prefix = prefix, payload = payload, target = target }
      end,
    },
    bnetApi = {},
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10, messageMaxAge = 86400, conversationMaxAge = 86400 }),
  }
end

local function payload(text)
  return {
    conversationKey = KEY,
    target = "Thrall-Nagrand",
    displayName = "Thrall-Nagrand",
    channel = "WOW",
    text = text,
  }
end

local function pendingEntries(runtime)
  local _, queue = next(runtime.pendingOutgoing)
  return queue or {}
end

local function send(text, configure)
  local whispers, addonMessages = {}, {}
  local runtime = newRuntime(whispers, addonMessages)
  local p = payload(text)
  if configure then
    configure(runtime, p)
  end
  local result = SendHandler.HandleSend(runtime, p, function() end)
  return result, whispers, addonMessages, runtime, p
end

return function()
  -- test_long_whisper_goes_out_as_four_whispers_in_order
  do
    local text = words(100)
    local result, whispers = send(text)
    assert(result == true, "sent")
    assert(#whispers == 4, "four whispers, got " .. #whispers)
    for index = 1, 4 do
      assert(whispers[index].text == words(25), "part " .. index .. " is 25 words")
      assert(whispers[index].target == "Thrall-Nagrand", "to the same target")
    end
  end

  -- test_every_part_gets_a_pending_entry_with_one_wire_id
  do
    local text = words(100)
    local _, _, _, runtime, p = send(text)
    local entries = pendingEntries(runtime)
    assert(#entries == 4, "one pending entry per part, got " .. #entries)
    for index, entry in ipairs(entries) do
      assert(entry.wireId == p.wireId and p.wireId ~= nil, "shared wire id")
      assert(entry.partIndex == index and entry.partCount == 4, "part position")
      assert(entry.text == words(25), "part text")
      assert(entry.fullText == text, "full text kept for the failed bubble")
    end
    assert(entries[1].join == nil and entries[2].join == " ", "join travels with the following part")
  end

  -- test_part_one_sends_identity_and_one_manifest_covers_the_rest
  do
    local _, _, addonMessages, _, p = send(words(100))
    assert(#addonMessages == 2, "identity + manifest, got " .. #addonMessages)
    local fp = Protocol.Fingerprint(words(25))
    assert(addonMessages[1].payload == "1|I|" .. p.wireId .. "|" .. fp, "identity for part 1: " .. addonMessages[1].payload)
    local manifest = "1|P|" .. p.wireId .. "|4|" .. fp .. "," .. fp .. "," .. fp .. "|sss"
    assert(addonMessages[2].payload == manifest, "manifest: " .. addonMessages[2].payload)
    assert(addonMessages[2].prefix == "WMRX", "same prefix as identity")
  end

  -- test_reply_link_goes_out_once
  do
    local _, _, addonMessages, _, p = send(words(100), function(runtime, sendPayload)
      runtime.livePresencePeers = { [KEY] = true }
      sendPayload.replyTo = { wireId = "their1", direction = "in", snippet = "you coming?" }
    end)
    assert(#addonMessages == 3, "identity + manifest + one reply link, got " .. #addonMessages)
    assert(string.sub(addonMessages[3].payload, 1, 4 + #p.wireId) == "1|Q|" .. p.wireId, "reply link last")
  end

  -- test_single_part_send_is_unchanged
  do
    local _, whispers, addonMessages, runtime, p = send("hello")
    assert(#whispers == 1 and whispers[1].text == "hello", "one whisper")
    assert(#addonMessages == 1 and string.sub(addonMessages[1].payload, 1, 4) == "1|I|", "identity only")
    local entries = pendingEntries(runtime)
    assert(#entries == 1 and entries[1].wireId == p.wireId, "one pending entry")
    assert(entries[1].partIndex == nil and entries[1].partCount == nil and entries[1].fullText == nil, "no part fields")
  end

  -- test_wire_text_needing_five_parts_sends_all_five
  do
    local result, whispers = send(words(110))
    assert(result == true, "sent")
    assert(#whispers == 5, "every part goes out, got " .. #whispers)
  end

  -- test_queued_long_whisper_splits_on_send_now
  do
    local locked = true
    local whispers = {}
    local runtime = newRuntime(whispers, {})
    runtime.isMythicLockdown = function()
      return locked
    end
    local text = words(100)
    SendHandler.HandleSend(runtime, payload(text), function() end)
    local queued = runtime.store.conversations[KEY].messages[1]
    assert(queued.delivery == "queued" and queued.text == text, "queued with its raw text")
    locked = false
    assert(QueuedSends.HandleAction(runtime, KEY, queued, "send_now", SendHandler, function() end) == true, "sent now")
    assert(#whispers == 4, "Send now splits too, got " .. #whispers)
  end

  -- test_bnet_failure_mid_loop_drops_every_part_entry
  do
    local calls = 0
    local runtime = newRuntime({}, {})
    runtime.bnetApi = {
      GetNumFriends = function()
        return 1
      end,
      GetFriendAccountInfo = function()
        return { bnetAccountID = 77, battleTag = "Jaina#1234", isOnline = true, gameAccountInfo = { gameAccountID = 9 } }
      end,
      SendWhisper = function()
        calls = calls + 1
        if calls == 2 then
          error("rejected")
        end
      end,
    }
    -- 1999 bytes: three 799-byte Battle.net parts.
    local result = SendHandler.HandleSend(runtime, {
      conversationKey = "me::BN::jaina",
      displayName = "Jaina#1234",
      battleTag = "Jaina#1234",
      bnetAccountID = 77,
      channel = "BN",
      text = words(200),
    }, function() end)
    assert(result == false, "the send failed")
    assert(calls == 2, "loop stopped at the failing part, calls " .. calls)
    assert(next(runtime.pendingOutgoing) == nil, "every pending entry of that message dropped")
  end
end
