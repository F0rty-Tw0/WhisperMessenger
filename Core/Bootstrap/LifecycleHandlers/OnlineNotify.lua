local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local OnlineWatch = ns.OnlineWatch or require("WhisperMessenger.Model.OnlineWatch")
-- stylua: ignore
local IncomingAlerts = ns.BootstrapEventBridgeIncomingAlerts or require("WhisperMessenger.Core.Bootstrap.EventBridge.IncomingAlerts")
local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local ChatPrint = ns.ChatPrint or require("WhisperMessenger.Util.ChatPrint")

-- "Notify when online" for flagged friends, driven only by Blizzard's own
-- friend events (no polling): FRIENDLIST_UPDATE for character friends,
-- BN_FRIEND_ACCOUNT_ONLINE / _OFFLINE for Battle.net friends.
local OnlineNotify = {}

local function announce(runtime, conversation)
  local name = conversation.nickname or conversation.displayName or "?"
  ChatPrint.Print(string.format(Localization.Text("%s is now online."), name))
  IncomingAlerts.PlaySound(runtime.accountState and runtime.accountState.settings)
end

local function stampSeen(runtime, conversation, isOnline)
  if isOnline == true then
    OnlineWatch.StampSeen(runtime, conversation)
  end
end

-- Also called from the Battle.net friend-list refresh for flagged contacts.
function OnlineNotify.Observe(runtime, conversationKey, conversation, isOnline)
  stampSeen(runtime, conversation, isOnline)
  if OnlineWatch.Observe(runtime, conversationKey, isOnline) then
    announce(runtime, conversation)
  end
end

-- The diff is limited to flagged character friends: one friend-list lookup
-- each, nothing for anyone else.
function OnlineNotify.handleFriendListUpdate(Bootstrap)
  local runtime = Bootstrap.runtime
  if runtime == nil or runtime.store == nil then
    return true
  end
  for key, conversation in pairs(runtime.store.conversations or {}) do
    if conversation.notifyOnline == true and conversation.channel ~= "BN" then
      OnlineNotify.Observe(runtime, key, conversation, OnlineWatch.ReadOnline(runtime, conversation))
    end
  end
  return true
end

function OnlineNotify.handleBNetAccountEvent(Bootstrap, rawAccountID, isOnline)
  local runtime = Bootstrap.runtime
  local bnetAccountID = BNetResolver.SanitizeAccountID(rawAccountID)
  if runtime == nil or runtime.store == nil or bnetAccountID == nil then
    return true
  end
  for key, conversation in pairs(runtime.store.conversations or {}) do
    if conversation.channel == "BN" and conversation.bnetAccountID == bnetAccountID then
      if conversation.notifyOnline == true then
        OnlineNotify.Observe(runtime, key, conversation, isOnline)
      else
        stampSeen(runtime, conversation, isOnline)
      end
    end
  end
  return true
end

ns.BootstrapLifecycleHandlersOnlineNotify = OnlineNotify
return OnlineNotify
