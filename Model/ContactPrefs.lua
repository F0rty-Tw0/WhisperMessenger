local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")

-- Per-conversation player preferences: mute, nickname, note and "Notify
-- when online". Stored on the
-- conversation record itself (like drafts), so they are saved with it and
-- removed with it. ponytail: mute has no duration; add one if asked.
local ContactPrefs = {}

ContactPrefs.MAX_NICKNAME_CHARS = 32

-- changes: any of { muted = bool, nickname = text, note = text,
-- notifyOnline = bool }. Blank text clears a field; a missing conversation
-- is ignored (prefs never create one).
function ContactPrefs.Apply(store, conversationKey, changes)
  local conversation = Store.Find(store, conversationKey)
  if conversation == nil or type(changes) ~= "table" then
    return
  end
  if changes.muted ~= nil then
    conversation.muted = changes.muted == true or nil
  end
  if changes.nickname ~= nil then
    local value = TextLimits.Trim(changes.nickname)
    conversation.nickname = value and TextLimits.CapChars(value, ContactPrefs.MAX_NICKNAME_CHARS) or nil
  end
  if changes.note ~= nil then
    local value = TextLimits.Trim(changes.note)
    conversation.note = value and TextLimits.CapBytes(value, TextLimits.MESSAGE_MAX_BYTES) or nil
  end
  if changes.notifyOnline ~= nil then
    conversation.notifyOnline = changes.notifyOnline == true or nil
  end
end

ns.ContactPrefs = ContactPrefs
return ContactPrefs
