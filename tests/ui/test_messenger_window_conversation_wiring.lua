-- Conversation wiring builds the pane with the window's message callbacks.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local ConversationWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ConversationWiring")
local ChannelContextMerger = require("WhisperMessenger.UI.ConversationPane.ChannelContextMerger")

local function makeWiring(windowOptions, nativeChrome, settingsConfig)
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
    settingsConfig = settingsConfig,
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

  -- test_empty_state_button_opens_the_dialog_like_the_title_bar_button
  do
    local factory = FakeUI.NewFactory()
    local popup = factory.CreateFrame("Frame", nil, nil)
    popup:SetWidth(420)
    popup.editBox = factory.CreateFrame("EditBox", nil, popup)
    popup.button1 = factory.CreateFrame("Button", nil, popup)
    popup.button2 = factory.CreateFrame("Button", nil, popup)
    popup.text = factory.CreateFrame("FontString", nil, popup)
    local focused = false
    popup.editBox.SetFocus = function()
      focused = true
    end
    rawset(_G, "StaticPopup_Show", function()
      return popup
    end)
    local threadPane = factory.CreateFrame("Frame", nil, nil)
    threadPane:SetSize(600, 400)
    local wiring = ConversationWiring.Create(factory, { threadPane = threadPane, windowOptions = {}, tabMode = "whispers" })
    local button = FindUI.ofType(wiring.conversation.headerEmpty, "Button")[1]
    button.scripts.OnClick(button)
    rawset(_G, "StaticPopup_Show", nil)
    assert(popup.editBox.width == 392, "input is sized to the laid-out popup, not left at its stale width")
    assert(focused == true, "input takes focus after the popup shows")
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

  -- test_first_render_honors_show_channel_context_off
  do
    local realForPane = ChannelContextMerger.ForPane
    local seen = {}
    ChannelContextMerger.ForPane = function(messages, selectedContact, conversation, enabled)
      seen[#seen + 1] = enabled
      return realForPane(messages, selectedContact, conversation, enabled)
    end
    makeWiring({}, nil, { showChannelContext = false })
    ChannelContextMerger.ForPane = realForPane
    assert(#seen >= 1 and seen[1] == false, "the pane's first render must see the option off, got " .. tostring(seen[1]))
  end

  -- test_pane_reads_show_channel_context_live
  do
    local settingsConfig = {}
    local wiring = makeWiring({}, nil, settingsConfig)
    assert(wiring.conversation.isChannelContextShown() == true, "shown by default")
    settingsConfig.showChannelContext = false
    assert(wiring.conversation.isChannelContextShown() == false, "reads the setting at call time, not at build time")
    settingsConfig.showChannelContext = true
    assert(wiring.conversation.isChannelContextShown() == true, "shown again once switched back on")
  end
end
