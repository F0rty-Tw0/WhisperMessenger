local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PlayerMenu = {}

-- Whisper lines store "WOW" or "BN" as message.channel.
local WHISPER_CHANNELS = { WOW = true, BN = true }

-- Group and channel lines carry their chat type ("GUILD", "CHANNEL") as
-- message.channel; their sender is still a WoW player. The line ID and chat
-- type let Blizzard's player menu report that line. Group lines carry
-- Battle.net ID 0 for ordinary players; Blizzard's menu reads any ID as "is a
-- Battle.net friend?" and hides Whisper when it isn't, so 0 is dropped.
local function buildItem(message)
  return {
    channel = message.channel == "BN" and "BN" or "WOW",
    displayName = message.playerName,
    guid = message.guid,
    bnetAccountID = message.bnetAccountID ~= 0 and message.bnetAccountID or nil,
    battleTag = message.battleTag,
    gameAccountName = message.gameAccountName,
    lineID = message.lineID,
    chatType = not WHISPER_CHANNELS[message.channel] and message.channel or nil,
  }
end

-- conversation (optional): { contact, rowActions }, rowActions being the
-- window's row actions table. In a whisper conversation the sender is the
-- selected contact, so the menu gets that contact and our entries; group
-- senders get a bare item.
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
  local actions = type(conversation) == "table" and conversation.rowActions or {}
  if type(contact) == "table" and (contact.channel == "WOW" or contact.channel == "BN") then
    return CM.Open(contact, anchorFrame, actions.onMarkUnread, actions.onUpdatePrefs) and true or false
  end

  -- A |K token is a protected Battle.net name: the WoW player menu can't
  -- target it, and it can't be ignored.
  local isProtected = string.find(message.playerName, "|K", 1, true) ~= nil
  if isProtected and message.channel ~= "BN" then
    return false
  end

  -- Group and channel senders: our Block… entry, or Unblock when blocked.
  -- Only those: a sender is not a contact row, so no Pin or Remove.
  local senderActions = nil
  local onIgnorePlayer = actions.onIgnorePlayer
  if type(onIgnorePlayer) == "function" and not isProtected then
    senderActions = {
      onIgnorePlayer = onIgnorePlayer,
      isPlayerBlocked = actions.isPlayerBlocked,
      onUnblockPlayer = actions.onUnblockPlayer,
    }
  end
  return CM.Open(buildItem(message), anchorFrame, nil, nil, senderActions) and true or false
end

ns.ChatBubblePlayerMenu = PlayerMenu
return PlayerMenu
