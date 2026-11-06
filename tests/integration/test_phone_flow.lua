local PhoneRuntime = require("tests.helpers.phone_runtime")

-- The phone layout through the real runtime: button, list, chat, back, and
-- what each does to unread counts, drafts and the Mythic pause notice.

local KEY, OTHER = PhoneRuntime.KEY, PhoneRuntime.OTHER
local run, clickRow, clickBack = PhoneRuntime.Run, PhoneRuntime.ClickRow, PhoneRuntime.ClickBack

return function()
  -- test_button_opens_the_list_and_leaves_unread_chats_unread
  run(nil, function(runtime)
    runtime.toggle()
    assert(runtime.window.isPhoneLayout, "phone layout")
    assert(runtime.window.frame.shown == true, "opens")
    assert(runtime.window.contactsPane:IsShown(), "on the list")
    assert(runtime.activeConversationKey == nil, "no chat opens by itself")
    assert(runtime.store.conversations[KEY].unreadCount == 2, "unread stays unread until the chat is opened")
  end)

  -- test_opening_a_chat_reads_it_and_back_returns_to_the_list
  run(nil, function(runtime)
    runtime.toggle()
    clickRow(runtime, KEY)
    assert(runtime.activeConversationKey == KEY, "chat open")
    assert(runtime.store.conversations[KEY].unreadCount == 0, "opening reads it")
    assert(runtime.window.contentPane:IsShown(), "chat on screen")
    clickBack(runtime)
    assert(runtime.activeConversationKey == nil, "back leaves the chat")
    assert(runtime.window.contactsPane:IsShown(), "list on screen")
  end)

  -- test_a_whisper_landing_on_the_list_stays_unread
  run(nil, function(runtime)
    runtime.toggle()
    clickRow(runtime, KEY)
    clickBack(runtime)
    assert(runtime.isConversationOpen(KEY) == false, "the list is not the chat, so a new whisper counts as unread")
  end)

  -- test_reopening_after_closing_in_a_chat_starts_on_the_list
  run(nil, function(runtime)
    runtime.toggle()
    clickRow(runtime, KEY)
    runtime.toggle()
    assert(runtime.window.frame.shown == false, "closes")
    runtime.toggle()
    assert(runtime.window.contactsPane:IsShown(), "list again")
    assert(not runtime.window.contentPane:IsShown(), "no chat showing")
    assert(not runtime.window.backButton:IsShown(), "no back button on the list")
  end)

  -- test_a_draft_survives_going_back_to_the_list
  run(nil, function(runtime)
    runtime.toggle()
    clickRow(runtime, KEY)
    local input = runtime.window.composer.input
    input:SetText("half a thought")
    input.scripts.OnTextChanged(input)
    clickBack(runtime)
    clickRow(runtime, OTHER)
    clickBack(runtime)
    clickRow(runtime, KEY)
    assert(runtime.window.composer.input:GetText() == "half a thought", "got " .. tostring(runtime.window.composer.input:GetText()))
  end)

  -- test_mythic_notice_shows_on_the_chat_opened_during_suspend
  run(nil, function(runtime)
    runtime.toggle()
    runtime.suspend()
    runtime.toggle()
    clickRow(runtime, KEY)
    local banner = runtime.window.conversation.activeStatusBanner
    assert(banner.shown == true and banner.text ~= "", "the pause notice shows in the chat")
    assert(runtime.window.composer.sendButton.disabled == true, "sending stays blocked")
    runtime.resume()
  end)

  -- test_mythic_notice_covers_the_chat_open_when_suspend_starts_and_clears_on_resume
  run(nil, function(runtime)
    runtime.toggle()
    clickRow(runtime, KEY)
    assert(runtime.window.composer.sendButton.disabled == false, "can send before suspend")
    runtime.suspend()
    assert(runtime.window.frame.shown == false, "suspend closes the window")
    runtime.toggle()
    assert(runtime.window.frame.shown == true, "reopens during suspend")
    assert(runtime.window.contactsPane:IsShown(), "on the list, like any open from the button")
    clickRow(runtime, KEY)
    local banner = runtime.window.conversation.activeStatusBanner
    assert(
      banner.text == "Messages are paused in Mythic content and will resume after you leave. To reply now, type /w and their name in the game's chat.",
      "got " .. tostring(banner.text)
    )
    assert(banner.shown == true, "the notice shows on the chat")
    assert(runtime.window.composer.sendButton.disabled == true, "sending stays blocked")
    runtime.resume()
    assert(banner.text == "" and banner.shown == false, "the notice clears after resume")
    assert(runtime.window.composer.sendButton.disabled == false, "sending works again")
  end)

  -- test_classic_setting_keeps_the_classic_window
  run({ phoneLayout = false }, function(runtime)
    runtime.toggle()
    assert(runtime.window.isPhoneLayout == nil, "classic window")
    assert(runtime.activeConversationKey == KEY, "the button still jumps to the unread chat")
  end)

  -- test_the_button_badge_keeps_counting_with_the_window_open
  run(nil, function(runtime)
    runtime.toggle()
    runtime.refreshWindow()
    local badge = runtime.icon.badge
    assert(badge:IsShown(), "the count stays on the button")
    assert(runtime.icon.badgeLabel:GetText() == "2", "got " .. tostring(runtime.icon.badgeLabel:GetText()))
  end)
end
