-- The coordinator coalesces incoming lines into one keyed refresh: contacts
-- rebuild only the dirty keys, and a line for a chat that is not on screen
-- refreshes the contact list without re-rendering the open conversation.

local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")

local function makeCoordinator()
  local h = { timers = {}, builds = {}, contactRefreshes = 0, selectionRefreshes = 0, shown = true }
  local window = {
    frame = {
      IsShown = function()
        return h.shown
      end,
    },
    refreshContacts = function()
      h.contactRefreshes = h.contactRefreshes + 1
    end,
    refreshSelection = function()
      h.selectionRefreshes = h.selectionRefreshes + 1
    end,
  }
  local runtime = {
    availabilityByGUID = {},
    sendStatusByConversation = {},
    now = function()
      return 1000
    end,
    activeConversationKey = "sel",
    store = { conversations = { sel = { messages = {} }, other = { messages = {} } } },
  }
  h.coordinator = WindowCoordinator.Create({
    runtime = runtime,
    buildContacts = function(dirtyKeys)
      h.builds[#h.builds + 1] = dirtyKeys or false
      return { { conversationKey = "sel", channel = "GUILD" }, { conversationKey = "other", channel = "GUILD" } }
    end,
    getWindow = function()
      return window
    end,
    cTimer = {
      After = function(_delay, fn)
        h.timers[#h.timers + 1] = fn
      end,
    },
  })
  return h
end

return function()
  -- test_incoming_lines_for_other_chats_refresh_contacts_only
  do
    local h = makeCoordinator()
    h.coordinator.scheduleIncomingRefresh("other")
    h.coordinator.scheduleIncomingRefresh("other")
    assert(#h.builds == 0, "scheduling must not refresh synchronously")
    assert(#h.timers == 1, "two lines arm one timer")
    h.timers[1]()
    assert(#h.builds == 1, "one flush builds contacts once, got " .. #h.builds)
    assert(h.builds[1] and h.builds[1].other == true, "the build receives the dirty keys")
    assert(h.contactRefreshes == 1 and h.selectionRefreshes == 0, "a non-selected line refreshes contacts only")
  end

  -- test_incoming_line_for_selected_chat_refreshes_selection
  do
    local h = makeCoordinator()
    h.coordinator.scheduleIncomingRefresh("other")
    h.coordinator.scheduleIncomingRefresh("sel")
    h.timers[1]()
    assert(h.selectionRefreshes == 1 and h.contactRefreshes == 0, "a selected line refreshes the open conversation")
  end

  -- test_whispers_in_one_frame_refresh_the_open_conversation_once
  do
    local h = makeCoordinator()
    h.coordinator.scheduleWhisperRefresh("other")
    h.coordinator.scheduleWhisperRefresh("sel")
    assert(#h.builds == 0, "whispers must not refresh synchronously")
    assert(#h.timers == 1, "two whispers arm one timer, got " .. #h.timers)
    h.timers[1]()
    assert(#h.builds == 1 and h.builds[1] == false, "one full contact build per frame")
    assert(h.selectionRefreshes == 1 and h.contactRefreshes == 0, "the open conversation is redrawn")
  end

  -- test_whisper_refresh_runs_while_window_hidden
  do
    local h = makeCoordinator()
    h.shown = false
    h.coordinator.scheduleWhisperRefresh("other")
    assert(#h.timers == 1, "a hidden window still arms the whisper refresh")
    h.timers[1]()
    assert(#h.builds == 1, "the hidden refresh rebuilds contacts for the icon badges")
  end

  -- test_direct_refresh_stays_full_and_synchronous
  do
    local h = makeCoordinator()
    h.coordinator.refreshWindow()
    assert(#h.builds == 1 and h.builds[1] == false, "a direct refresh builds every contact at once")
  end
end
