local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Common = ns.BootstrapLifecycleHandlersCommon or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common")
local Relationship = ns.Relationship or require("WhisperMessenger.Model.Relationship")

local RelationshipRefresh = {}

local REPAINT_DELAY = 2
local EVENTS = {
  CLUB_MEMBER_ADDED = true,
  CLUB_MEMBER_REMOVED = true,
  PLAYER_GUILD_UPDATE = true,
  FRIENDLIST_UPDATE = true,
  BN_FRIEND_LIST_SIZE_CHANGED = true,
}

local function shouldRepaint(Bootstrap, runtime)
  if Bootstrap._inMythicContent or not Relationship.IsEnabled(runtime) then
    return false
  end
  return type(runtime.isWindowVisible) ~= "function" or runtime.isWindowVisible() ~= false
end

local function readFriendCount()
  local api = _G.C_FriendList
  if type(api) ~= "table" or type(api.GetNumFriends) ~= "function" then
    return nil
  end
  local ok, count = pcall(api.GetNumFriends)
  if not ok or type(count) ~= "number" then
    return nil
  end
  return count
end

-- FRIENDLIST_UPDATE also fires on every friend login, logout and ShowFriends
-- call. Only a changed friend count is a membership change; an unreadable
-- count always counts as one.
local function friendListChanged(Bootstrap)
  local count = readFriendCount()
  if count ~= nil and count == Bootstrap._relationshipFriendCount then
    return false
  end
  Bootstrap._relationshipFriendCount = count
  return true
end

-- A membership change drops the relationship cache and repaints once, 2 s
-- after the last event of a burst (a trailing debounce: every event bumps the
-- token, only the newest timer repaints). Without timers it repaints at once.
-- Returns true when the event invalidated.
function RelationshipRefresh.handle(Bootstrap, event, unit)
  local runtime = Bootstrap.runtime
  if not EVENTS[event] or runtime == nil then
    return false
  end
  if event == "PLAYER_GUILD_UPDATE" and unit ~= nil and unit ~= "player" then
    return false
  end
  if event == "FRIENDLIST_UPDATE" and not friendListChanged(Bootstrap) then
    return false
  end

  Relationship.Invalidate(runtime)
  if not shouldRepaint(Bootstrap, runtime) then
    return true
  end

  local token = (Bootstrap._relationshipRefreshToken or 0) + 1
  Bootstrap._relationshipRefreshToken = token
  local function repaint()
    if Bootstrap._relationshipRefreshToken == token and not Bootstrap._inMythicContent then
      Common.refreshRuntimeWindow(Bootstrap)
    end
  end
  if not Common.scheduleAfter(REPAINT_DELAY, repaint) then
    repaint()
  end
  return true
end

ns.BootstrapLifecycleHandlersRelationshipRefresh = RelationshipRefresh
return RelationshipRefresh
