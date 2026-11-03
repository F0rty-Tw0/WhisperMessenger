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

-- Guild/community members only: Battle.net zones come from the friend list.
function ZoneNotify.IsArmedGuildContact(conversation)
  return type(conversation) == "table" and conversation.notifyZone == true and conversation.channel ~= "BN" and conversation.guid ~= nil
end

-- The stored zone of an offline member is stale, so it is not a zone.
local function observePresence(runtime, conversation, PresenceCache, presence)
  local zone = presence == "online" and PresenceCache.GetZone(conversation.guid) or nil
  return ZoneNotify.Observe(runtime, conversation, zone)
end

-- One member read per armed guild/community contact, nothing for anyone
-- else. Returns true when any contact alerted.
function ZoneNotify.handleRosterUpdate(Bootstrap, PresenceCache)
  local runtime = Bootstrap.runtime
  if runtime == nil or runtime.store == nil or PresenceCache == nil then
    return false
  end
  local alerted = false
  for _, conversation in pairs(runtime.store.conversations or {}) do
    if ZoneNotify.IsArmedGuildContact(conversation) then
      local presence = PresenceCache.RefreshPresence(conversation.guid)
      alerted = observePresence(runtime, conversation, PresenceCache, presence) or alerted
    end
  end
  return alerted
end

-- A window refresh just freshened this contact's presence: a zone the cache
-- picked up without a roster event still alerts. The row's menu tick clears
-- with it. Returns true when it alerted.
function ZoneNotify.ObserveContact(runtime, item, PresenceCache, presence)
  local conversations = runtime.store and runtime.store.conversations
  local conversation = conversations and conversations[item.conversationKey]
  if not ZoneNotify.IsArmedGuildContact(conversation) then
    return false
  end
  if not observePresence(runtime, conversation, PresenceCache, presence) then
    return false
  end
  item.notifyZone = nil
  return true
end

ns.BootstrapLifecycleHandlersZoneNotify = ZoneNotify
return ZoneNotify
