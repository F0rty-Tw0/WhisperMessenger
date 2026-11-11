local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SoundPlayer = ns.SoundPlayer or require("WhisperMessenger.Core.SoundPlayer")
local MessageRequests = ns.MessageRequests or require("WhisperMessenger.Model.MessageRequests")

-- Sound + taskbar flash for an alerting message: a whisper that passed
-- AlertPolicy.ShouldAlert, or a group line mentioning the player.
local IncomingAlerts = {}

IncomingAlerts.REQUEST_SOUND_DEFAULT = "ping"
IncomingAlerts.SENT_SOUND_DEFAULT = "chime"

-- A request the player asked to hear: inbox on, sound on, not muted.
function IncomingAlerts.IsAudibleRequest(conversation, settings)
  return type(conversation) == "table"
    and type(settings) == "table"
    and MessageRequests.IsRequest(conversation, settings)
    and conversation.muted ~= true
    and settings.playSoundOnRequest == true
end

function IncomingAlerts.PlayRequestSound(settings)
  SoundPlayer.PlayKey(settings.requestSound or IncomingAlerts.REQUEST_SOUND_DEFAULT)
end

-- The notification sound alone, when the player turned it on. A mention
-- plays its own pick; unset, it plays the whisper pick.
function IncomingAlerts.PlaySound(settings, kind)
  if type(settings) ~= "table" or settings.playSoundOnWhisper ~= true then
    return
  end
  if kind == "mention" then
    SoundPlayer.PlayKey(settings.mentionSound or settings.notificationSound or SoundPlayer.DEFAULT_SOUND_KEY)
  else
    SoundPlayer.Play(settings)
  end
end

-- A whisper sent from the window, when the player turned its sound on.
function IncomingAlerts.PlaySentSound(settings)
  if type(settings) == "table" and settings.playSoundOnSend == true then
    SoundPlayer.PlayKey(settings.sentSound or IncomingAlerts.SENT_SOUND_DEFAULT)
  end
end

function IncomingAlerts.Notify(settings, kind)
  if type(settings) ~= "table" then
    return
  end
  IncomingAlerts.PlaySound(settings, kind)
  -- Blizzard's chat frame flashes the taskbar icon itself, but never sees
  -- whispers hidden from the default chat. Default on; a second flash from
  -- Blizzard is harmless.
  if settings.flashTaskbarOnWhisper ~= false and type(_G.FlashClientIcon) == "function" then
    _G.FlashClientIcon()
  end
end

-- The parts of a long whisper arrive as separate whispers before anything
-- marks them as parts, so a conversation alerts at most once per window.
local ALERT_WINDOW_SECONDS = 2

-- True when conversationKey alerted within the window; otherwise records
-- now as its last alert.
function IncomingAlerts.Throttled(runtime, conversationKey, now)
  if conversationKey == nil or type(now) ~= "number" then
    return false
  end
  runtime.lastAlertAtByConversation = runtime.lastAlertAtByConversation or {}
  local lastAlertAt = runtime.lastAlertAtByConversation[conversationKey]
  if lastAlertAt ~= nil and now >= lastAlertAt and now - lastAlertAt < ALERT_WINDOW_SECONDS then
    return true
  end
  runtime.lastAlertAtByConversation[conversationKey] = now
  return false
end

ns.BootstrapEventBridgeIncomingAlerts = IncomingAlerts
return IncomingAlerts
