local PhoneRuntime = require("tests.helpers.phone_runtime")
local Poller = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.Poller")
local FakeUI = require("tests.helpers.fake_ui")

-- Ways into a chat that do not start with a click on the list: a whisper
-- auto-opening the window, and /r.

local KEY = PhoneRuntime.KEY
local run, finishSlide = PhoneRuntime.Run, PhoneRuntime.FinishSlide

-- Types into a chat box watched by the real poller, as the player would.
local function typeInChat(runtime, text)
  local factory = FakeUI.NewFactory()
  local editBox = factory.CreateFrame("EditBox", "ChatBox", _G.UIParent)
  Poller.Install(runtime, runtime.autoOpenHooks, {
    isSuspended = function()
      return false
    end,
    getNumChatWindows = function()
      return 1
    end,
    getEditBox = function()
      return editBox
    end,
  })
  editBox:SetText(text)
  editBox._hookScripts.OnTextChanged[1](editBox, true)
  finishSlide(runtime)
end

local function assertOnChat(runtime)
  assert(runtime.activeConversationKey == KEY, "got " .. tostring(runtime.activeConversationKey))
  assert(runtime.window.frame.shown == true, "window open")
  assert(runtime.window.contentPane:IsShown(), "chat on screen")
  assert(not runtime.window.contactsPane:IsShown(), "list gone")
  assert(runtime.window.backButton:IsShown(), "a way back to the list")
end

return function()
  -- test_auto_open_from_a_closed_window_lands_on_the_chat
  run({ autoOpenIncoming = true }, function(runtime)
    PhoneRuntime.ReceiveWhisper(runtime)
    assertOnChat(runtime)
  end)

  -- test_auto_open_on_the_list_slides_to_the_chat_without_taking_the_keyboard
  run({ autoOpenIncoming = true }, function(runtime)
    runtime.toggle()
    assert(runtime.window.contactsPane:IsShown(), "on the list")
    PhoneRuntime.ReceiveWhisper(runtime)
    assertOnChat(runtime)
    assert(not runtime.window.composer.input:HasFocus(), "the player did not ask to type")
  end)

  -- test_without_auto_open_the_list_stays_put
  run(nil, function(runtime)
    runtime.toggle()
    PhoneRuntime.ReceiveWhisper(runtime)
    assert(runtime.activeConversationKey == nil, "no chat opens by itself")
    assert(runtime.window.contactsPane:IsShown(), "still on the list")
    assert(runtime.store.conversations[KEY].unreadCount == 3, "and it counts as unread")
  end)

  -- test_auto_open_leaves_an_open_chat_alone
  run({ autoOpenIncoming = true }, function(runtime)
    runtime.toggle()
    PhoneRuntime.ClickRow(runtime, PhoneRuntime.OTHER)
    PhoneRuntime.ReceiveWhisper(runtime)
    assert(runtime.activeConversationKey == PhoneRuntime.OTHER, "the open chat stays")
  end)

  -- test_reply_from_a_closed_window_lands_on_the_chat_ready_to_type
  run(nil, function(runtime)
    runtime.lastIncomingWhisperKey = KEY
    typeInChat(runtime, "/r on my way")
    assertOnChat(runtime)
    assert(runtime.window.composer.input:HasFocus(), "ready to type")
    assert(runtime.window.composer.input:GetText() == "on my way", "got " .. tostring(runtime.window.composer.input:GetText()))
  end)

  -- test_reply_from_the_list_slides_to_the_chat
  run(nil, function(runtime)
    runtime.toggle()
    runtime.lastIncomingWhisperKey = KEY
    typeInChat(runtime, "/r ")
    assertOnChat(runtime)
    assert(runtime.window.composer.input:HasFocus(), "ready to type")
  end)

  -- test_reply_over_settings_returns_to_a_phone_sized_chat
  run(nil, function(runtime)
    runtime.toggle()
    local phoneWidth = runtime.window.frame:GetWidth()
    runtime.window.setOptionsVisible(true)
    assert(runtime.window.frame:GetWidth() > phoneWidth, "settings widen the window")
    runtime.lastIncomingWhisperKey = KEY
    typeInChat(runtime, "/r ")
    assertOnChat(runtime)
    assert(runtime.window.frame:GetWidth() == phoneWidth, "back to phone size")
  end)
end
