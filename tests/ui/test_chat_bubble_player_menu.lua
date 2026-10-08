local FakeUI = require("tests.helpers.fake_ui")
local PlayerMenu = require("WhisperMessenger.UI.ChatBubble.PlayerMenu")

return function()
  local factory = FakeUI.NewFactory()
  local anchor = factory.CreateFrame("Frame", nil, nil)

  -- test_open_routes_incoming_wow_whisper_to_friend_dropdown
  do
    local opened
    local stub = {
      Open = function(item, anchorFrame)
        opened = { item = item, anchor = anchorFrame }
        return true
      end,
    }

    local message = {
      direction = "in",
      channel = "WOW",
      playerName = "Arthas-Area52",
      guid = "Player-3678-0A1B2C3D",
    }
    local ok = PlayerMenu.Open(message, anchor, stub)

    assert(ok == true, "expected Open to return true on success")
    assert(opened ~= nil, "expected the contacts ContextMenu.Open to be called")
    assert(opened.item.channel == "WOW", "expected channel WOW, got " .. tostring(opened.item.channel))
    assert(opened.item.displayName == "Arthas-Area52", "expected displayName 'Arthas-Area52', got " .. tostring(opened.item.displayName))
    assert(opened.item.guid == "Player-3678-0A1B2C3D", "expected guid forwarded, got " .. tostring(opened.item.guid))
    assert(opened.anchor == anchor, "expected the anchor frame to be forwarded")
  end

  -- test_open_routes_incoming_bnet_whisper_with_account_id
  do
    local opened
    local stub = {
      Open = function(item, anchorFrame)
        opened = { item = item, anchor = anchorFrame }
        return true
      end,
    }

    local message = {
      direction = "in",
      channel = "BN",
      playerName = "Jaina#1234",
      bnetAccountID = 12345,
      battleTag = "Jaina#1234",
    }
    local ok = PlayerMenu.Open(message, anchor, stub)

    assert(ok == true, "expected BN open to return true")
    assert(opened.item.channel == "BN", "expected channel BN")
    assert(opened.item.bnetAccountID == 12345, "expected bnetAccountID 12345, got " .. tostring(opened.item.bnetAccountID))
    assert(opened.item.battleTag == "Jaina#1234", "expected battleTag forwarded, got " .. tostring(opened.item.battleTag))
  end

  -- test_open_uses_selected_whisper_contact_with_callbacks
  do
    local opened
    local stub = {
      Open = function(item, anchorFrame, onMarkUnread, onUpdatePrefs)
        opened = { item = item, anchor = anchorFrame, onMarkUnread = onMarkUnread, onUpdatePrefs = onUpdatePrefs }
        return true
      end,
    }
    local contact = { channel = "BN", conversationKey = "me::BN::jaina#1234", displayName = "Jaina", muted = true }
    local markUnread, updatePrefs = function() end, function() end

    local ok = PlayerMenu.Open(
      { direction = "in", channel = "BN", playerName = "Jaina#1234" },
      anchor,
      stub,
      { contact = contact, onMarkUnread = markUnread, onUpdatePrefs = updatePrefs }
    )

    assert(ok == true, "expected whisper-contact open to return true")
    assert(opened.item == contact, "expected the selected contact as the menu item")
    assert(opened.anchor == anchor, "expected the anchor frame to be forwarded")
    assert(opened.onMarkUnread == markUnread and opened.onUpdatePrefs == updatePrefs, "expected both callbacks forwarded")
  end

  -- test_open_in_group_conversation_uses_bare_sender_item
  do
    local opened
    local stub = {
      Open = function(item, _anchorFrame, onMarkUnread, onUpdatePrefs)
        opened = { item = item, onMarkUnread = onMarkUnread, onUpdatePrefs = onUpdatePrefs }
        return true
      end,
    }
    local group = { channel = "GUILD", conversationKey = "me::GUILD::guild", displayName = "Guild" }

    local ok = PlayerMenu.Open(
      { direction = "in", channel = "WOW", playerName = "Thrall-Doomhammer" },
      anchor,
      stub,
      { contact = group, onMarkUnread = function() end, onUpdatePrefs = function() end }
    )

    assert(ok == true, "expected group-sender open to return true")
    assert(opened.item ~= group and opened.item.displayName == "Thrall-Doomhammer", "expected the bare sender item")
    assert(opened.onMarkUnread == nil and opened.onUpdatePrefs == nil, "expected no WM callbacks for group senders")
  end

  -- test_open_on_channel_line_sender_opens_player_menu
  -- Channel and group lines store their chat type ("CHANNEL", "GUILD") on
  -- the message; the sender is still a WoW player, not the chat.
  do
    local opened
    local stub = {
      Open = function(item)
        opened = item
        return true
      end,
    }
    local trade = { channel = "CHANNEL", conversationKey = "channel::me::trade", displayName = "Trade" }

    PlayerMenu.Open(
      { direction = "in", channel = "CHANNEL", playerName = "Guldanhand-Kazzak", guid = "Player-1-0A" },
      anchor,
      stub,
      { contact = trade }
    )

    assert(opened.channel == "WOW", "expected the sender as a WOW player, got " .. tostring(opened.channel))
  end

  -- test_channel_sender_menu_offers_our_ignore
  do
    local opened
    local stub = {
      Open = function(item, _anchorFrame, _onMarkUnread, _onUpdatePrefs, rowActions)
        opened = { item = item, rowActions = rowActions }
        return true
      end,
    }
    local onIgnorePlayer = function() end

    PlayerMenu.Open(
      { direction = "in", channel = "CHANNEL", playerName = "Hilan-Kazzak" },
      anchor,
      stub,
      { contact = { channel = "CHANNEL" }, onIgnorePlayer = onIgnorePlayer }
    )

    assert(opened.rowActions and opened.rowActions.onIgnorePlayer == onIgnorePlayer, "group senders get our Ignore… entry")
  end

  -- test_channel_sender_menu_knows_who_is_blocked
  do
    local opened
    local stub = {
      Open = function(_item, _anchorFrame, _onMarkUnread, _onUpdatePrefs, rowActions)
        opened = rowActions
        return true
      end,
    }
    local isPlayerBlocked, onUnblockPlayer = function() end, function() end
    PlayerMenu.Open({ direction = "in", channel = "CHANNEL", playerName = "Hilan-Kazzak" }, anchor, stub, {
      contact = { channel = "CHANNEL" },
      onIgnorePlayer = function() end,
      isPlayerBlocked = isPlayerBlocked,
      onUnblockPlayer = onUnblockPlayer,
    })
    assert(
      opened.isPlayerBlocked == isPlayerBlocked and opened.onUnblockPlayer == onUnblockPlayer,
      "a blocked sender gets Unblock, not Block… again"
    )
  end

  -- test_open_refuses_outgoing_messages
  -- You don't open a player menu on yourself.
  do
    local called = false
    local stub = {
      Open = function()
        called = true
        return true
      end,
    }

    local ok = PlayerMenu.Open({
      direction = "out",
      channel = "WOW",
      playerName = "Me",
    }, anchor, stub)

    assert(ok == false, "expected Open to refuse outgoing messages")
    assert(called == false, "expected ContextMenu.Open NOT to be called for outgoing messages")
  end

  -- test_open_returns_false_without_a_player_name
  do
    local called = false
    local stub = {
      Open = function()
        called = true
        return true
      end,
    }

    local ok = PlayerMenu.Open({ direction = "in", channel = "WOW" }, anchor, stub)
    assert(ok == false, "expected Open to refuse messages without a playerName")
    assert(called == false, "expected ContextMenu.Open NOT to be called when name is missing")
  end

  -- test_open_returns_false_when_context_menu_is_unavailable
  do
    local ok = PlayerMenu.Open({
      direction = "in",
      channel = "WOW",
      playerName = "Thrall-Doomhammer",
    }, anchor, nil)
    -- Without a contacts ContextMenu impl injected and no ns lookup in the
    -- test sandbox, Open should fail gracefully instead of erroring.
    assert(ok == false, "expected Open to return false when the menu impl is unavailable")
  end
  -- test_channel_sender_item_carries_line_and_chat_type
  -- Blizzard's player menu needs both to offer Report Player for the line.
  do
    local opened
    local stub = {
      Open = function(item)
        opened = item
        return true
      end,
    }

    PlayerMenu.Open(
      { direction = "in", channel = "CHANNEL", playerName = "Hilan-Kazzak", lineID = 4242 },
      anchor,
      stub,
      { contact = { channel = "CHANNEL" } }
    )

    assert(opened.lineID == 4242, "expected the line ID, got " .. tostring(opened.lineID))
    assert(opened.chatType == "CHANNEL", "expected chat type CHANNEL, got " .. tostring(opened.chatType))
  end

  -- test_guild_sender_item_carries_guild_chat_type
  do
    local opened
    local stub = {
      Open = function(item)
        opened = item
        return true
      end,
    }

    PlayerMenu.Open(
      { direction = "in", channel = "GUILD", playerName = "Thrall-Doomhammer", lineID = 7 },
      anchor,
      stub,
      { contact = { channel = "GUILD" } }
    )

    assert(opened.lineID == 7 and opened.chatType == "GUILD", "expected the guild line and chat type")
  end

  -- test_guild_sender_with_zero_bnet_id_gets_no_bnet_id
  -- Guild and group lines carry Battle.net ID 0 for ordinary players; passed
  -- on, Blizzard's menu treats the sender as a non-friend and hides Whisper.
  do
    local opened
    local stub = {
      Open = function(item)
        opened = item
        return true
      end,
    }

    PlayerMenu.Open(
      { direction = "in", channel = "GUILD", playerName = "Thrall-Doomhammer", bnetAccountID = 0 },
      anchor,
      stub,
      { contact = { channel = "GUILD" } }
    )

    assert(opened.bnetAccountID == nil, "expected no Battle.net ID, got " .. tostring(opened.bnetAccountID))
  end

  -- test_guild_sender_who_is_a_bnet_friend_keeps_their_bnet_id
  do
    local opened
    local stub = {
      Open = function(item)
        opened = item
        return true
      end,
    }

    PlayerMenu.Open(
      { direction = "in", channel = "GUILD", playerName = "Jaina-Proudmoore", bnetAccountID = 99001 },
      anchor,
      stub,
      { contact = { channel = "GUILD" } }
    )

    assert(opened.bnetAccountID == 99001, "expected Battle.net ID 99001, got " .. tostring(opened.bnetAccountID))
  end

  -- test_protected_name_opens_no_player_menu
  -- A |K token is a protected Battle.net name; the WoW player menu can't use it.
  do
    local called = false
    local stub = {
      Open = function()
        called = true
        return true
      end,
    }

    local ok = PlayerMenu.Open(
      { direction = "in", channel = "COMMUNITY", playerName = "|Kq1|k", lineID = 8 },
      anchor,
      stub,
      { contact = { channel = "COMMUNITY" } }
    )

    assert(ok == false, "expected no menu for a protected name")
    assert(called == false, "expected ContextMenu.Open NOT to be called")
  end
end
