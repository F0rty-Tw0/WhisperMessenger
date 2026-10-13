local ContactsList = require("WhisperMessenger.UI.ContactsList")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")

-- A whoPlayer callback passed to MessengerWindow.Create reaches every
-- shift-click spot. Contact rows, the chat header name and channel senders are wired here.

return function()
  local conversations = {
    ["me::WOW::arthas-area52"] = {
      displayName = "Arthas-Area52",
      channel = "WOW",
      lastActivityAt = 10,
      messages = {},
    },
  }
  local whoNames = {}
  local window = MessengerWindow.Create(FakeUI.NewFactory(), {
    contacts = ContactsList.BuildItems(conversations),
    whoPlayer = function(name)
      whoNames[#whoNames + 1] = name
      return true
    end,
  })

  -- test_shift_click_on_contact_row_sends_who
  whoNames = {}
  local originalShift = _G.IsShiftKeyDown
  _G.IsShiftKeyDown = function()
    return true
  end
  local row = window.contacts.rows[1]
  row.scripts.OnClick(row, "LeftButton")
  _G.IsShiftKeyDown = originalShift

  assert(#whoNames == 1 and whoNames[1] == "Arthas-Area52", "contact row shift-click reaches whoPlayer")

  -- test_shift_click_on_header_name_sends_who
  whoNames = {}
  window.selectConversation("me::WOW::arthas-area52")
  window.conversation.headerName.mouseOver = true
  _G.IsShiftKeyDown = function()
    return true
  end
  local headerUp = window.conversation.headerFrame:GetScript("OnMouseUp")
  headerUp(window.conversation.headerFrame, "LeftButton")
  _G.IsShiftKeyDown = originalShift

  assert(#whoNames == 1 and whoNames[1] == "Arthas-Area52", "header name shift-click reaches whoPlayer")

  -- test_shift_click_on_channel_sender_sends_who
  whoNames = {}
  local incoming = { id = "1", direction = "in", kind = "user", text = "wts", sentAt = 10, playerName = "Bob-Realm" }
  local trade = { displayName = "Trade", channel = "CHANNEL", lastActivityAt = 10, messages = { incoming } }
  local channelConversations = { ["me::CHANNEL::trade"] = trade }
  local channelWindow = MessengerWindow.Create(FakeUI.NewFactory(), {
    contacts = ContactsList.BuildItems(channelConversations),
    initialTabMode = "groups",
    onSelectConversation = function(conversationKey, item)
      return { selectedContact = item, conversation = channelConversations[conversationKey] }
    end,
    whoPlayer = function(name)
      whoNames[#whoNames + 1] = name
      return true
    end,
  })
  local channelRow = channelWindow.contacts.rows[1]
  channelRow.scripts.OnClick()
  local sender = FindUI.find(channelWindow.frame, function(node)
    return type(node._wmPlayerMenuOpener) == "function" and node.scripts and node.scripts.OnMouseUp ~= nil
  end)
  assert(sender ~= nil, "incoming channel sender has a player-menu handler")
  _G.IsShiftKeyDown = function()
    return true
  end
  sender.scripts.OnMouseUp(sender, "LeftButton")
  _G.IsShiftKeyDown = originalShift

  assert(#whoNames == 1 and whoNames[1] == "Bob-Realm", "channel sender shift-click reaches whoPlayer")
end
