local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PlayerMenu = {}

local function buildItem(message)
  return {
    channel = message.channel or "WOW",
    displayName = message.playerName,
    guid = message.guid,
    bnetAccountID = message.bnetAccountID,
    battleTag = message.battleTag,
    gameAccountName = message.gameAccountName,
  }
end

function PlayerMenu.Open(message, anchorFrame, contextMenu)
  if type(message) ~= "table" then
    return false
  end
  if message.direction ~= "in" then
    return false
  end
  if type(message.playerName) ~= "string" or message.playerName == "" then
    return false
  end

  local CM = contextMenu or ns.ContactsListContextMenu
  if type(CM) ~= "table" or type(CM.Open) ~= "function" then
    return false
  end

  return CM.Open(buildItem(message), anchorFrame) and true or false
end

ns.ChatBubblePlayerMenu = PlayerMenu
return PlayerMenu
