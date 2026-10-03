local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PlayerMenu = {}

-- Whisper lines store "WOW" or "BN" as message.channel.
local WHISPER_CHANNELS = { WOW = true, BN = true }

-- Group and channel lines carry their chat type ("GUILD", "CHANNEL") as
-- message.channel; their sender is still a WoW player. The line ID and chat
-- type let Blizzard's player menu report that line.
local function buildItem(message)
  return {
    channel = message.channel == "BN" and "BN" or "WOW",
    displayName = message.playerName,
    guid = message.guid,
    bnetAccountID = message.bnetAccountID,
    battleTag = message.battleTag,
    gameAccountName = message.gameAccountName,
    lineID = message.lineID,
    chatType = not WHISPER_CHANNELS[message.channel] and message.channel or nil,
  }
end

-- conversation (optional): { contact, onMarkUnread, onUpdatePrefs, onIgnorePlayer,
-- isPlayerBlocked, onUnblockPlayer }. In a
-- whisper conversation the sender is the selected contact, so the menu gets
-- that contact and our entries; group senders get a bare item.
function PlayerMenu.Open(message, anchorFrame, contextMenu, conversation)
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

  local contact = type(conversation) == "table" and conversation.contact or nil
  if type(contact) == "table" and (contact.channel == "WOW" or contact.channel == "BN") then
    return CM.Open(contact, anchorFrame, conversation.onMarkUnread, conversation.onUpdatePrefs) and true or false
  end

  -- A |K token is a protected Battle.net name: the WoW player menu can't
  -- target it, and it can't be ignored.
  local isProtected = string.find(message.playerName, "|K", 1, true) ~= nil
  if isProtected and message.channel ~= "BN" then
    return false
  end

  -- Group and channel senders: our Block… entry, or Unblock when blocked.
  local rowActions = nil
  local onIgnorePlayer = type(conversation) == "table" and conversation.onIgnorePlayer or nil
  if type(onIgnorePlayer) == "function" and not isProtected then
    rowActions = {
      onIgnorePlayer = onIgnorePlayer,
      isPlayerBlocked = conversation.isPlayerBlocked,
      onUnblockPlayer = conversation.onUnblockPlayer,
    }
  end
  return CM.Open(buildItem(message), anchorFrame, nil, nil, rowActions) and true or false
end

ns.ChatBubblePlayerMenu = PlayerMenu
return PlayerMenu
