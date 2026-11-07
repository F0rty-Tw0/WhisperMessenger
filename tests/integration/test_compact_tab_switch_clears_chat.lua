local CompactRuntime = require("tests.helpers.compact_runtime")
local FindUI = require("tests.helpers.find_ui")

-- Tapping another tab while a chat is open behaves like the back arrow: the
-- runtime selection is cleared, so a later whisper cannot bounce the window
-- back into the old chat or count as read.

local KEY = CompactRuntime.KEY
local run, finishSlide = CompactRuntime.Run, CompactRuntime.FinishSlide

-- 1 Whispers, 2 Groups. The slide is the caller's to finish on the compact window.
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
    CompactRuntime.ClickRow(runtime, KEY)
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
    CompactRuntime.ClickRow(runtime, KEY)
    tapTab(runtime, 2)
    finishSlide(runtime)
    CompactRuntime.ReceiveWhisper(runtime)
    assert(runtime.activeConversationKey == nil, "no bounce back into the old chat")
    assert(onList(runtime), "window stays on the list")
    assert(runtime.store.conversations[KEY].unreadCount == 1, "the new message stays unread")
    assert(runtime.isConversationOpen(KEY) == false)
  end)

  -- test_opening_a_chat_after_a_programmatic_tab_change_still_lands_on_it
  run(nil, function(runtime)
    runtime.toggle()
    CompactRuntime.ClickRow(runtime, KEY)
    tapTab(runtime, 2)
    finishSlide(runtime)
    assert(runtime.startConversation("Arthas-Area52") == true)
    finishSlide(runtime)
    assert(runtime.activeConversationKey == KEY and runtime.window.getTabMode() == "whispers")
    assert(runtime.window.contentPane:IsShown(), "slid into the chat")
  end)

  -- test_request_follow_in_the_compact_layout_survives_the_nested_clear
  -- Replying accepts a request: RequestFollow switches to Whispers from inside
  -- the refresh, which now clears the selection first, then selects the key.
  run({ requestsInbox = true }, function(runtime)
    runtime.store.conversations[KEY].request = true
    runtime.toggle()
    runtime.refreshWindow()
    runtime.window.setTabMode("requests")
    CompactRuntime.ClickRow(runtime, KEY)
    assert(runtime.activeConversationKey == KEY and runtime.window.getTabMode() == "requests")
    runtime.store.conversations[KEY].request = nil
    runtime.refreshWindow()
    finishSlide(runtime)
    assert(runtime.window.getTabMode() == "whispers", "followed to Whispers")
    assert(runtime.activeConversationKey == KEY, "the followed chat stays selected")
    assert(runtime.window.contentPane:IsShown(), "and stays on screen")
  end)

  -- test_request_follow_keeps_the_new_messages_divider
  -- The follow switches tabs with the chat already selected: that must not
  -- run a selection of nothing, which would drop the divider for good.
  run({ requestsInbox = true }, function(runtime)
    runtime.store.conversations[KEY].request = true
    runtime.toggle()
    runtime.refreshWindow()
    runtime.window.setTabMode("requests")
    CompactRuntime.ClickRow(runtime, KEY)
    runtime.store.conversations[KEY].request = nil
    runtime.refreshWindow()
    finishSlide(runtime)
    assert(runtime.unreadDivider and runtime.unreadDivider.conversationKey == KEY, "the divider survives the follow")
    assert(runtime.window.contentPane:IsShown() and not onList(runtime), "and the window ends on the chat view")
  end)

  -- test_tab_tap_on_the_list_with_no_chat_open_skips_the_full_refresh
  run(nil, function(runtime)
    runtime.toggle()
    assert(runtime.activeConversationKey == nil and onList(runtime))
    local refreshes, refreshSelection = 0, runtime.window.refreshSelection
    runtime.window.refreshSelection = function(...)
      refreshes = refreshes + 1
      return refreshSelection(...)
    end
    tapTab(runtime, 2)
    assert(runtime.window.getTabMode() == "groups", "the tab still switches")
    assert(refreshes == 0, "no full window refresh, got " .. refreshes)
  end)

  -- test_classic_tab_switch_keeps_its_old_selection_behaviour
  run({ compactLayout = false }, function(runtime)
    runtime.toggle()
    assert(runtime.activeConversationKey == KEY)
    tapTab(runtime, 2)
    assert(runtime.window.getTabMode() == "groups")
    assert(runtime.activeConversationKey == KEY, "classic is unchanged (known stale key, follow-up note)")
  end)
end
