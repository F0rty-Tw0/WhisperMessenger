local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ZoneWatch = ns.ZoneWatch or require("WhisperMessenger.Model.ZoneWatch")
-- stylua: ignore
local IncomingAlerts = ns.BootstrapEventBridgeIncomingAlerts or require("WhisperMessenger.Core.Bootstrap.EventBridge.IncomingAlerts")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local ChatPrint = ns.ChatPrint or require("WhisperMessenger.Util.ChatPrint")
local DisplayName = ns.DisplayName or require("WhisperMessenger.Util.DisplayName")

-- "Notify when they change zone", driven only by events presence already
-- handles (no polling): guild/community roster events for guild members, the
-- debounced Battle.net friend-list refresh for Battle.net friends.
local ZoneNotify = {}

-- Same chat line + sound as "Notify when online".
local function announce(runtime, conversation, from, to)
  local name = conversation.nickname or DisplayName.Format(conversation.displayName) or "?"
  ChatPrint.Print(string.format(Localization.Text("%s changed zone from %s to %s."), name, from, to))
  IncomingAlerts.PlaySound(runtime.accountState and runtime.accountState.settings)
end

-- Returns true when it alerted (and so disarmed the watch).
function ZoneNotify.Observe(runtime, conversation, zone)
  local from, to = ZoneWatch.Observe(conversation, zone)
  if from == nil then
    return false
  end
  announce(runtime, conversation, from, to)
  return true
end

-- One member read per armed guild/community contact, nothing for anyone
-- else. The stored zone of an offline member is stale, so it is not a zone.
-- Returns true when any contact alerted.
function ZoneNotify.handleRosterUpdate(Bootstrap, PresenceCache)
  local runtime = Bootstrap.runtime
  if runtime == nil or runtime.store == nil or PresenceCache == nil then
    return false
  end
  local alerted = false
  for _, conversation in pairs(runtime.store.conversations or {}) do
    if conversation.notifyZone == true and conversation.channel ~= "BN" and conversation.guid ~= nil then
      local online = PresenceCache.RefreshPresence(conversation.guid) == "online"
      local zone = online and PresenceCache.GetZone(conversation.guid) or nil
      alerted = ZoneNotify.Observe(runtime, conversation, zone) or alerted
    end
  end
  return alerted
end

ns.BootstrapLifecycleHandlersZoneNotify = ZoneNotify
return ZoneNotify
