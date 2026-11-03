local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Common = ns.BootstrapLifecycleHandlersCommon or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common")
local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local ZoneNotify = ns.BootstrapLifecycleHandlersZoneNotify or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.ZoneNotify")

-- Guild zones only change with GUILD_ROSTER_UPDATE, which the game sends
-- after a roster request (repeats within 10 s are ignored server-side).
-- While a guild/community contact has "Notify when they change zone" on, ask
-- once per interval; the first tick that finds nothing armed ends the poll.
local ZoneRosterPoll = {}

ZoneRosterPoll.INTERVAL_SECONDS = 60

local function inMythicContent(runtime)
  return type(runtime.isMythicLockdown) == "function" and runtime.isMythicLockdown() == true
end

-- Safe to call on every arm and every PLAYER_ENTERING_WORLD: a running poll
-- is left alone.
function ZoneRosterPoll.Start(runtime)
  if runtime == nil or runtime.store == nil or runtime.zoneRosterPollPending then
    return
  end
  if not ZoneNotify.HasArmedGuildContact(runtime) then
    return
  end
  -- Same rule as the login presence rebuild: no guild reads in mythic content.
  if not inMythicContent(runtime) then
    FlavorCompat.RequestGuildRoster()
  end
  runtime.zoneRosterPollPending = Common.scheduleAfter(ZoneRosterPoll.INTERVAL_SECONDS, function()
    runtime.zoneRosterPollPending = false
    ZoneRosterPoll.Start(runtime)
  end)
end

ns.BootstrapLifecycleHandlersZoneRosterPoll = ZoneRosterPoll
return ZoneRosterPoll
