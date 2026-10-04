local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SoundPlayer = ns.SoundPlayer or require("WhisperMessenger.Core.SoundPlayer")

-- Sound + taskbar flash for an alerting message: a whisper that passed
-- AlertPolicy.ShouldAlert, or a group line mentioning the player.
local IncomingAlerts = {}

-- The notification sound alone, when the player turned it on.
function IncomingAlerts.PlaySound(settings)
  if type(settings) == "table" and settings.playSoundOnWhisper == true then
    SoundPlayer.Play(settings)
  end
end

function IncomingAlerts.Notify(settings)
  if type(settings) ~= "table" then
    return
  end
  IncomingAlerts.PlaySound(settings)
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
