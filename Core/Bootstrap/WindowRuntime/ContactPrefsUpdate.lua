local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactPrefs = ns.ContactPrefs or require("WhisperMessenger.Model.ContactPrefs")
local OnlineWatch = ns.OnlineWatch or require("WhisperMessenger.Model.OnlineWatch")
local ZoneWatch = ns.ZoneWatch or require("WhisperMessenger.Model.ZoneWatch")
-- stylua: ignore
local ZoneRosterPoll = ns.BootstrapLifecycleHandlersZoneRosterPoll or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.ZoneRosterPoll")

-- Mute / nickname / note / notify-when-online / zone watch from the contact row menu.
local ContactPrefsUpdate = {}

-- Returns true when the conversation's prefs were saved.
function ContactPrefsUpdate.Apply(runtime, item, changes)
  local key = item and item.conversationKey
  if key == nil then
    return false
  end
  ContactPrefs.Apply(runtime.store, key, changes)
  -- Record the friend's state now so their next login is a change.
  if changes and changes.notifyOnline == true then
    OnlineWatch.Observe(runtime, key, OnlineWatch.ReadOnline(runtime, runtime.store.conversations[key]))
  end
  -- The zone the row shows now is the one a change is measured from; a
  -- guild member's next zone needs the roster asked for.
  if changes and changes.notifyZone == true then
    ZoneWatch.Observe(runtime.store.conversations[key], item.areaName)
    ZoneRosterPoll.Start(runtime)
  end
  return true
end

ns.BootstrapWindowRuntimeContactPrefsUpdate = ContactPrefsUpdate
return ContactPrefsUpdate
