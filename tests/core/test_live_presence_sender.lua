local Sender = require("WhisperMessenger.Core.Bootstrap.LivePresenceSender")
local LivePresence = require("WhisperMessenger.Model.LivePresence")
local Store = require("WhisperMessenger.Model.ConversationStore")

local function newRuntime(nowRef, sent, bnSent)
  return {
    now = function()
      return nowRef.value
    end,
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    accountState = { settings = {} },
    chatApi = {
      RegisterAddonMessagePrefix = function()
        return true
      end,
      SendAddonMessage = function(prefix, payload, channel, target)
        table.insert(sent, { prefix = prefix, payload = payload, channel = channel, target = target })
        return true
      end,
    },
    bnetApi = {
      SendGameData = function(gameAccountID, prefix, payload)
        table.insert(bnSent, { gameAccountID = gameAccountID, prefix = prefix, payload = payload })
        return true
      end,
      GetNumFriends = function()
        return 1
      end,
      GetFriendAccountInfo = function(index)
        if index == 1 then
          return {
            bnetAccountID = 77,
            battleTag = "Jaina#1234",
            isOnline = true,
            gameAccountInfo = { gameAccountID = 9001, isOnline = true },
          }
        end
        return nil
      end,
    },
  }
end

local function wowConversation(runtime, key, displayName)
  local conv = Store.EnsureConversation(runtime.store, key)
  conv.displayName = displayName
  conv.channel = "WOW"
  return conv
end

return function()
  local key = "me::WOW::thrall-nagrand"
  local contact = { conversationKey = key, displayName = "Thrall-Nagrand", channel = "WOW" }

  -- test_typing_is_only_sent_to_known_addon_peers
  do
    local now = { value = 100 }
    local sent, bnSent = {}, {}
    local runtime = newRuntime(now, sent, bnSent)
    wowConversation(runtime, key, "Thrall-Nagrand")

    assert(Sender.OnComposerText(runtime, contact, "hel") == false, "unknown peer: nothing sent")
    assert(#sent == 0, "unknown peer: no addon message")

    LivePresence.RecordPeer(runtime, key)
    assert(Sender.OnComposerText(runtime, contact, "hel") == true, "known peer: typing start sent")
    assert(#sent == 1 and sent[1].prefix == "WMRX" and sent[1].payload == "1|T|1", "typing start payload")
    assert(sent[1].channel == "WHISPER" and sent[1].target == "Thrall-Nagrand", "typing start addressed to the contact")

    -- throttled inside the resend interval
    now.value = 101
    assert(Sender.OnComposerText(runtime, contact, "hell") == false, "throttled")
    assert(#sent == 1, "throttled: no extra message")

    -- refreshed after the interval so the peer's indicator never expires mid-typing
    now.value = 100 + Sender.TYPING_RESEND_INTERVAL
    assert(Sender.OnComposerText(runtime, contact, "hello") == true, "resent after interval")
    assert(#sent == 2 and sent[2].payload == "1|T|1", "resend is another start")

    -- clearing the box sends one stop
    assert(Sender.OnComposerText(runtime, contact, "") == true, "clearing sends stop")
    assert(#sent == 3 and sent[3].payload == "1|T|0", "stop payload")
    assert(Sender.OnComposerText(runtime, contact, "") == false, "second clear is silent")
    assert(#sent == 3, "no duplicate stop")

    -- slash commands are not typing
    now.value = 200
    assert(Sender.OnComposerText(runtime, contact, "/dance") == false, "slash command ignored")
    assert(#sent == 3, "slash command sends nothing")
  end

  -- test_typing_respects_setting_and_restricted_content
  do
    local now = { value = 100 }
    local sent, bnSent = {}, {}
    local runtime = newRuntime(now, sent, bnSent)
    wowConversation(runtime, key, "Thrall-Nagrand")
    LivePresence.RecordPeer(runtime, key)

    runtime.accountState.settings.shareTypingStatus = false
    assert(Sender.OnComposerText(runtime, contact, "x") == false, "setting off: nothing sent")
    runtime.accountState.settings.shareTypingStatus = nil

    runtime.isCompetitiveContent = function()
      return true
    end
    assert(Sender.OnComposerText(runtime, contact, "x") == false, "competitive: nothing sent")
    runtime.isCompetitiveContent = nil

    runtime.isMythicLockdown = function()
      return true
    end
    assert(Sender.OnComposerText(runtime, contact, "x") == false, "mythic lockdown: nothing sent")
    assert(#sent == 0, "restricted paths send nothing")
  end

  -- test_switching_conversation_stops_old_and_starts_new
  do
    local now = { value = 100 }
    local sent, bnSent = {}, {}
    local runtime = newRuntime(now, sent, bnSent)
    wowConversation(runtime, key, "Thrall-Nagrand")
    LivePresence.RecordPeer(runtime, key)
    local key2 = "me::WOW::jaina-dalaran"
    wowConversation(runtime, key2, "Jaina-Dalaran")
    LivePresence.RecordPeer(runtime, key2)
    local contact2 = { conversationKey = key2, displayName = "Jaina-Dalaran", channel = "WOW" }

    assert(Sender.OnComposerText(runtime, contact, "abc") == true, "start on first")
    now.value = 101
    assert(Sender.OnComposerText(runtime, contact2, "abc") == true, "start on second despite interval")
    assert(#sent == 3, "stop + start after switching")
    assert(sent[2].payload == "1|T|0" and sent[2].target == "Thrall-Nagrand", "old conversation stopped")
    assert(sent[3].payload == "1|T|1" and sent[3].target == "Jaina-Dalaran", "new conversation started")
  end

  -- test_battle_net_typing_uses_game_account
  do
    local now = { value = 100 }
    local sent, bnSent = {}, {}
    local runtime = newRuntime(now, sent, bnSent)
    local bnKey = "bnet::77"
    local conv = Store.EnsureConversation(runtime.store, bnKey)
    conv.channel = "BN"
    conv.bnetAccountID = 77
    conv.battleTag = "Jaina#1234"
    conv.displayName = "Jaina"
    LivePresence.RecordPeer(runtime, bnKey)
    local bnContact = { conversationKey = bnKey, displayName = "Jaina", channel = "BN", bnetAccountID = 77 }

    assert(Sender.OnComposerText(runtime, bnContact, "hey") == true, "bnet typing sent")
    assert(#sent == 0, "no character addon message for bnet")
    assert(#bnSent == 1 and bnSent[1].gameAccountID == 9001 and bnSent[1].payload == "1|T|1", "bnet typing via game account")
  end

  -- test_read_receipt_sent_once_for_visible_conversation
  do
    local now = { value = 100 }
    local sent, bnSent = {}, {}
    local runtime = newRuntime(now, sent, bnSent)
    local conv = wowConversation(runtime, key, "Thrall-Nagrand")
    conv.messages = { { direction = "in", kind = "user", wireId = "in1", text = "hi", sentAt = 90 } }

    assert(Sender.SyncReadReceipts(runtime, contact) == false, "unknown peer: no receipt")
    LivePresence.RecordPeer(runtime, key)
    assert(Sender.SyncReadReceipts(runtime, contact) == true, "receipt sent")
    assert(#sent == 1 and sent[1].payload == "1|S|in1" and sent[1].target == "Thrall-Nagrand", "receipt payload")
    assert(conv.messages[1].receiptSentAt == 100, "receipt recorded on the message")
    assert(Sender.SyncReadReceipts(runtime, contact) == false, "receipt not repeated")
    assert(#sent == 1, "no duplicate receipt")

    table.insert(conv.messages, { direction = "in", kind = "user", wireId = "in2", text = "again", sentAt = 110 })
    runtime.accountState.settings.shareReadReceipts = false
    assert(Sender.SyncReadReceipts(runtime, contact) == false, "setting off: no receipt")
    runtime.accountState.settings.shareReadReceipts = nil
    assert(Sender.SyncReadReceipts(runtime, nil) == false, "no selection: no receipt")
    assert(Sender.SyncReadReceipts(runtime, contact) == true, "next message receipted")
    assert(sent[2].payload == "1|S|in2", "second receipt payload")
  end
end
