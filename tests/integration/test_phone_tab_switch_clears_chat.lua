local PhoneRuntime = require("tests.helpers.phone_runtime")
local FindUI = require("tests.helpers.find_ui")

-- Tapping another tab while a chat is open behaves like the back arrow: the
-- runtime selection is cleared, so a later whisper cannot bounce the window
-- back into the old chat or count as read.

local KEY = PhoneRuntime.KEY
local run, finishSlide = PhoneRuntime.Run, PhoneRuntime.FinishSlide

-- 1 Whispers, 2 Groups. The slide is the caller's to finish on the phone.
local function tapTab(runtime, index)
  local button = FindUI.ofType(runtime.window.tabToggle.frame, "Button")[index]
  button.scripts.OnClick(button)
end

local function onList(runtime)
  return runtime.window.contactsPane:IsShown() and not runtime.window.contentPane:IsShown()
end

return function()
  -- test_other_tab_tap_from_a_chat_clears_the_runtime_selection
  run(nil, function(runtime)
    runtime.toggle()
    PhoneRuntime.ClickRow(runtime, KEY)
    assert(runtime.activeConversationKey == KEY)
    tapTab(runtime, 2)
    finishSlide(runtime)
    assert(runtime.activeConversationKey == nil, "cleared like the back arrow")
    assert(runtime.window.getTabMode() == "groups")
    assert(onList(runtime))
  end)

  -- test_a_whisper_after_an_other_tab_tap_stays_unread_on_the_list
  run(nil, function(runtime)
    runtime.toggle()
    PhoneRuntime.ClickRow(runtime, KEY)
    tapTab(runtime, 2)
    finishSlide(runtime)
    PhoneRuntime.ReceiveWhisper(runtime)
    assert(runtime.activeConversationKey == nil, "no bounce back into the old chat")
    assert(onList(runtime), "window stays on the list")
    assert(runtime.store.conversations[KEY].unreadCount == 1, "the new message stays unread")
    assert(runtime.isConversationOpen(KEY) == false)
  end)

  -- test_opening_a_chat_after_a_programmatic_tab_change_still_lands_on_it
  run(nil, function(runtime)
    runtime.toggle()
    PhoneRuntime.ClickRow(runtime, KEY)
    tapTab(runtime, 2)
    finishSlide(runtime)
    assert(runtime.startConversation("Arthas-Area52") == true)
    finishSlide(runtime)
    assert(runtime.activeConversationKey == KEY and runtime.window.getTabMode() == "whispers")
    assert(runtime.window.contentPane:IsShown(), "slid into the chat")
  end)

  -- test_request_follow_in_the_phone_layout_survives_the_nested_clear
  -- Replying accepts a request: RequestFollow switches to Whispers from inside
  -- the refresh, which now clears the selection first, then selects the key.
  run({ requestsInbox = true }, function(runtime)
    runtime.store.conversations[KEY].request = true
    runtime.toggle()
    runtime.refreshWindow()
    runtime.window.setTabMode("requests")
    PhoneRuntime.ClickRow(runtime, KEY)
    assert(runtime.activeConversationKey == KEY and runtime.window.getTabMode() == "requests")
    runtime.store.conversations[KEY].request = nil
    runtime.refreshWindow()
    finishSlide(runtime)
    assert(runtime.window.getTabMode() == "whispers", "followed to Whispers")
    assert(runtime.activeConversationKey == KEY, "the followed chat stays selected")
    assert(runtime.window.contentPane:IsShown(), "and stays on screen")
  end)

  -- test_classic_tab_switch_keeps_its_old_selection_behaviour
  run({ phoneLayout = false }, function(runtime)
    runtime.toggle()
    assert(runtime.activeConversationKey == KEY)
    tapTab(runtime, 2)
    assert(runtime.window.getTabMode() == "groups")
    assert(runtime.activeConversationKey == KEY, "classic is unchanged (known stale key, follow-up note)")
  end)
end
