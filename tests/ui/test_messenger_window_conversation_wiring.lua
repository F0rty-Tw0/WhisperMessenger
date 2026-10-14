-- Conversation wiring builds the pane with the window's message callbacks.
local FakeUI = require("tests.helpers.fake_ui")
local ConversationWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ConversationWiring")

local function makeWiring(windowOptions, nativeChrome)
  local factory = FakeUI.NewFactory()
  local threadPane = factory.CreateFrame("Frame", nil, nil)
  threadPane:SetSize(600, 400)
  windowOptions.selectedContact = windowOptions.selectedContact or { conversationKey = "me::WOW::jaina", channel = "WOW" }
  windowOptions.conversation = windowOptions.conversation or { messages = {} }
  return ConversationWiring.Create(factory, {
    threadPane = threadPane,
    windowOptions = windowOptions,
    nativeChrome = nativeChrome,
    tabMode = "whispers",
  })
end

return function()
  -- test_message_actions_reach_the_window_callback
  do
    local seen
    local wiring = makeWiring({
      onMessageAction = function(contact, message, action)
        seen = { contact, message, action }
        return true
      end,
    })
    local message = { text = "hi" }
    wiring.conversation.transcript.onMessageAction(message, "copy")
    assert(seen and seen[1].conversationKey == "me::WOW::jaina", "action carries the open contact")
    assert(seen[2] == message and seen[3] == "copy", "action carries the message and action")
  end

  -- test_reply_is_handled_by_the_window_not_the_callback
  do
    local called = false
    local wiring = makeWiring({
      onMessageAction = function()
        called = true
      end,
    })
    assert(wiring.messageActions.onMessageAction({}, {}, "reply") == true, "reply handled locally")
    assert(called == false, "reply never reaches the window callback")
  end

  -- test_native_chrome_hides_the_empty_header
  do
    local wiring = makeWiring({}, true)
    assert(wiring.conversation.hideEmptyHeader == true, "HUD chrome hides the empty header")
  end

  -- test_first_paint_hides_invite_link_when_disabled
  do
    local wiring = makeWiring({
      canInviteContact = function()
        return false
      end,
    })
    assert(wiring.conversation.headerAddonBadge:IsShown() == false, "invite link is hidden from the first paint when invites are disabled")
  end
end
