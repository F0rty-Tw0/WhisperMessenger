local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AddonGreetings = ns.AddonGreetings or require("WhisperMessenger.Model.AddonGreetings")
local AddonComm = ns.AddonComm or require("WhisperMessenger.Transport.AddonComm")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local OutgoingDelivery = ns.OutgoingDelivery or require("WhisperMessenger.Model.OutgoingDelivery")

-- Router glue for addon greetings. The router only calls in with payloads
-- free of secret values; whispers replayed after a chat lockdown are never
-- tagged, since their announcement could not be heard during the lock.
local AddonGreetingIngest = {}

-- The name stored on a whisper tagged by CraftScan's own channel.
AddonGreetingIngest.CRAFT_SCAN_NAME = "CraftScan"

local function settingsOf(state)
  return state.accountState and state.accountState.settings or nil
end

-- Hide after the fact: the alert already played. A conversation the whisper
-- opened goes with it; otherwise only the line and its unread count do.
local function hideStored(state, conversation, stored)
  local messages = conversation.messages or {}
  if stored.isNew and #messages == 1 and messages[1] == stored.message then
    return Store.Remove(state.store, stored.conversationKey)
  end
  if OutgoingDelivery.Remove(state.store, stored.conversationKey, stored.message) and stored.countedUnread then
    conversation.unreadCount = math.max(0, (conversation.unreadCount or 0) - 1)
  end
  return conversation
end

-- CraftScan's client speaks on its own prefix right after the customer's
-- "found you via CraftScan" whisper; the payload is encoded and never read.
local function tagLate(state, payload)
  local stored = AddonGreetings.ClaimStored(state, payload.playerName, state.now and state.now() or 0)
  local conversation = stored and Store.Find(state.store, stored.conversationKey)
  if conversation == nil then
    return nil
  end
  if AddonGreetings.Mode(settingsOf(state)) == AddonGreetings.MODE_HIDE then
    return hideStored(state, conversation, stored)
  end
  stored.message.addonGreeting = AddonGreetingIngest.CRAFT_SCAN_NAME
  if stored.isNew then
    AddonGreetingIngest.ClassifyNew(state, conversation)
  end
  return conversation
end

-- CHAT_MSG_ADDON on robots.txt or CRAFT_SCAN. Returns the conversation a
-- late tag changed, so the window refreshes.
function AddonGreetingIngest.HandleAddonMessage(state, payload)
  if payload.channel ~= "WHISPER" then
    return nil
  end
  if payload.prefix == AddonComm.PREFIX_CRAFT_SCAN then
    return tagLate(state, payload)
  end
  AddonGreetings.Record(state, payload.playerName, payload.text, state.now and state.now() or 0)
  return nil
end

-- After a live character whisper is stored: an untagged one may still be
-- tagged by CraftScan's own channel; a tagged new conversation may go to
-- Requests.
function AddonGreetingIngest.AfterStore(state, contact, payload, conversationKey, message, isNew, isActive)
  if payload.replayedAt ~= nil or contact == nil then
    return
  end
  if message.addonGreeting ~= nil then
    if isNew then
      AddonGreetingIngest.ClassifyNew(state, state.store.conversations[conversationKey])
    end
    return
  end
  local stored = { conversationKey = conversationKey, message = message, isNew = isNew, countedUnread = not isActive }
  AddonGreetings.NoteWhisper(state, contact.contactKey, state.now and state.now() or 0, stored)
end

-- Returns the addon name for a live character whisper that follows an
-- announcement, and whether the "Hide" setting keeps it out of the window.
function AddonGreetingIngest.ClaimForWhisper(state, contact, payload, now)
  if payload.replayedAt ~= nil or contact == nil then
    return nil, false
  end
  local tag = AddonGreetings.Claim(state, contact.contactKey, now)
  if tag == nil then
    return nil, false
  end
  -- A tagged whisper, kept or hidden, is the sender's newest: an older
  -- untagged one must not be tagged late in its place.
  AddonGreetings.NoteWhisper(state, contact.contactKey, now, nil)
  return tag, AddonGreetings.Mode(settingsOf(state)) == AddonGreetings.MODE_HIDE
end

-- "Send to Requests": the conversation this greeting opened waits in Requests.
function AddonGreetingIngest.ClassifyNew(state, conversation)
  if type(conversation) == "table" and AddonGreetings.Mode(settingsOf(state)) == AddonGreetings.MODE_REQUESTS then
    conversation.request = true
  end
end

ns.EventRouterAddonGreetingIngest = AddonGreetingIngest
return AddonGreetingIngest
