-- The transcript's player menu takes the window's row actions as one table
-- (conversation.rowActions) and picks the entries each kind of sender gets.
local PlayerMenu = require("WhisperMessenger.UI.ChatBubble.PlayerMenu")

-- Opens the menu and returns what the contacts menu was opened with.
local function open(message, conversation)
  local opened
  local stub = {
    Open = function(item, _anchorFrame, onMarkUnread, onUpdatePrefs, rowActions)
      opened = { item = item, onMarkUnread = onMarkUnread, onUpdatePrefs = onUpdatePrefs, rowActions = rowActions }
      return true
    end,
  }
  PlayerMenu.Open(message, {}, stub, conversation)
  return opened
end

local function allRowActions()
  local rowActions = {}
  for _, name in ipairs({ "onPin", "onRemove", "onMarkUnread", "onUpdatePrefs", "onIgnorePlayer", "onUnblockPlayer", "isPlayerBlocked" }) do
    rowActions[name] = function() end
  end
  return rowActions
end

local CHANNEL_LINE = { direction = "in", channel = "CHANNEL", playerName = "Hilan-Kazzak" }

return function()
  -- test_whisper_contact_menu_gets_mark_unread_and_prefs_from_the_row_actions
  do
    local rowActions = allRowActions()
    local contact = { channel = "WOW", conversationKey = "me::WOW::arthas", displayName = "Arthas" }
    local opened = open({ direction = "in", channel = "WOW", playerName = "Arthas" }, { contact = contact, rowActions = rowActions })
    assert(opened.item == contact, "the selected contact is the menu item")
    assert(opened.onMarkUnread == rowActions.onMarkUnread and opened.onUpdatePrefs == rowActions.onUpdatePrefs, "both callbacks reach the menu")
    assert(opened.rowActions == nil, "no Pin, Remove or Block… from inside the chat")
  end

  -- test_group_sender_menu_gets_only_the_block_actions
  do
    local rowActions = allRowActions()
    local opened = open(CHANNEL_LINE, { contact = { channel = "CHANNEL" }, rowActions = rowActions })
    local senderActions = opened.rowActions
    assert(type(senderActions) == "table", "sender menu gets our entries")
    assert(senderActions.onIgnorePlayer == rowActions.onIgnorePlayer, "sender gets Block…")
    assert(senderActions.isPlayerBlocked == rowActions.isPlayerBlocked, "sender menu can tell who is blocked")
    assert(senderActions.onUnblockPlayer == rowActions.onUnblockPlayer, "sender gets Unblock")
    assert(senderActions.onPin == nil and senderActions.onRemove == nil, "a sender is not a contact row: no Pin or Remove")
    assert(opened.onMarkUnread == nil and opened.onUpdatePrefs == nil, "no Mark unread or prefs for a sender")
  end

  -- test_actions_outside_the_row_actions_table_are_not_read
  do
    local opened = open(CHANNEL_LINE, { contact = { channel = "CHANNEL" }, onIgnorePlayer = function() end })
    assert(opened.rowActions == nil, "only conversation.rowActions feeds the menu")
  end

  -- test_whisper_contact_menu_opens_without_row_actions
  do
    local contact = { channel = "WOW", conversationKey = "me::WOW::arthas", displayName = "Arthas" }
    local opened = open({ direction = "in", channel = "WOW", playerName = "Arthas" }, { contact = contact })
    assert(opened.item == contact and opened.onMarkUnread == nil, "menu opens with no entries of ours")
  end

  -- test_group_sender_menu_has_no_block_entry_without_the_action
  do
    local rowActions = allRowActions()
    rowActions.onIgnorePlayer = nil
    local opened = open(CHANNEL_LINE, { contact = { channel = "CHANNEL" }, rowActions = rowActions })
    assert(opened.rowActions == nil, "no onIgnorePlayer, no entries of ours")
  end
end
