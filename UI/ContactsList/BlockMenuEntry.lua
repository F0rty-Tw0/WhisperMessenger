local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local IgnorePrompt = ns.IgnorePrompt or require("WhisperMessenger.UI.Shared.IgnorePrompt")
local IgnoreList = ns.IgnoreList or require("WhisperMessenger.Model.Filters.IgnoreList")

-- A whisper row's "Block…" entry, or "Unblock" when the player is already
-- blocked. WoW whisper rows only: Battle.net friends and groups aren't one
-- character. rowActions: onIgnorePlayer(name, reason), and optionally
-- isPlayerBlocked(name) and onUnblockPlayer(name).
local BlockMenuEntry = {}

local function isBlocked(rowActions, name)
  return type(rowActions.isPlayerBlocked) == "function"
    and type(rowActions.onUnblockPlayer) == "function"
    and rowActions.isPlayerBlocked(name) == true
end

function BlockMenuEntry.Add(rootDescription, item, rowActions)
  local onIgnorePlayer = type(rowActions) == "table" and rowActions.onIgnorePlayer
  if type(onIgnorePlayer) ~= "function" or item.channel ~= "WOW" or item.displayName == nil then
    return
  end
  local name = IgnoreList.CharacterName(item.displayName, item.guid)
  if isBlocked(rowActions, name) then
    rootDescription:CreateButton(Localization.Text("Unblock"), function()
      rowActions.onUnblockPlayer(name)
    end)
    return
  end
  rootDescription:CreateButton(Localization.Text("Block…"), function()
    IgnorePrompt.AskReason(function(reason)
      onIgnorePlayer(name, reason)
    end)
  end)
end

ns.ContactsListBlockMenuEntry = BlockMenuEntry
return BlockMenuEntry
