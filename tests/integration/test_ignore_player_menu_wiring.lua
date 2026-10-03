local ContactsList = require("WhisperMessenger.UI.ContactsList")
local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local BubbleContextMenu = require("WhisperMessenger.UI.ChatBubble.ContextMenu")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")

-- The window's onIgnorePlayer callback reaches both "Ignore…" menus: the
-- contact row menu and the message menu in a channel chat.
local TRADE = "me::CHANNEL::trade"

return function()
  local incoming = { id = "1", direction = "in", kind = "user", text = "wts boost", sentAt = 10, playerName = "Spammer-Realm" }
  local conversations = {
    [TRADE] = { displayName = "Trade", channel = "CHANNEL", lastActivityAt = 10, messages = { incoming } },
    ["me::WOW::arthas"] = { displayName = "Arthas", channel = "WOW", lastActivityAt = 1, messages = {} },
  }
  local ignored
  local function createWindow(tabMode)
    return MessengerWindow.Create(FakeUI.NewFactory(), {
      contacts = ContactsList.BuildItems(conversations),
      initialTabMode = tabMode,
      onSelectConversation = function(conversationKey, item)
        return { selectedContact = item, conversation = conversations[conversationKey] }
      end,
      onIgnorePlayer = function(name, reason)
        ignored = { name = name, reason = reason }
      end,
    })
  end
  local window = createWindow("whispers")

  -- test_row_menu_receives_the_ignore_callback
  local rowActions
  local originalOpen = ContextMenu.Open
  rawset(ContextMenu, "Open", function(_item, _anchor, _onMarkUnread, _onUpdatePrefs, actions)
    rowActions = actions
    return true
  end)
  local row = window.contacts.rows[1]
  row.scripts.OnClick(row, "RightButton")
  rawset(ContextMenu, "Open", originalOpen)
  assert(rowActions and type(rowActions.onIgnorePlayer) == "function", "row menu gets onIgnorePlayer")
  rowActions.onIgnorePlayer("Arthas", "spam")
  assert(ignored and ignored.name == "Arthas" and ignored.reason == "spam", "row callback reaches the window option")

  -- test_channel_message_menu_offers_ignore_sender
  window = createWindow("groups")
  local trade
  for _, candidate in ipairs(window.contacts.rows) do
    if candidate.item and candidate.item.conversationKey == TRADE then
      trade = candidate
    end
  end
  trade.scripts.OnClick()
  local bubble = FindUI.find(window.frame, function(node)
    return node._wmMessage == incoming and node.scripts and node.scripts.OnMouseDown ~= nil
  end)
  assert(bubble ~= nil, "channel message bubble rendered")
  local menuOptions
  local originalBubbleOpen = BubbleContextMenu.Open
  rawset(BubbleContextMenu, "Open", function(_text, _anchor, options)
    menuOptions = options
    return true
  end)
  bubble.scripts.OnMouseDown(bubble, "RightButton")
  rawset(BubbleContextMenu, "Open", originalBubbleOpen)
  assert(menuOptions and type(menuOptions.onIgnoreSender) == "function", "message menu offers Ignore sender…")
end
