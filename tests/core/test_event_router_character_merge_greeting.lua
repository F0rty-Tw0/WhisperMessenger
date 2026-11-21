local Router = require("WhisperMessenger.Core.EventRouter")
local World = require("tests.helpers.character_merge_world")

-- A friend's character whose first whisper opens the friend's Battle.net
-- chat: that chat is new, so a hidden addon greeting takes it away again
-- instead of leaving an empty chat behind.
local K, B, NAME, FRIEND = World.K, World.B, World.NAME, World.FRIEND

local function hideState()
  local state = World.NewState(FRIEND)
  state.accountState.settings.addonGreetings = "hide"
  return state
end

local function whisper(state)
  return Router.HandleEvent(state, "CHAT_MSG_WHISPER", { text = "found you via CraftScan", playerName = NAME, guid = "Player-1", lineID = 900 })
end

local function craftScan(state)
  return Router.HandleEvent(state, "CHAT_MSG_ADDON", { prefix = "CRAFT_SCAN", text = "^1^encoded", channel = "WHISPER", playerName = NAME })
end

local function announce(state)
  return Router.HandleEvent(state, "CHAT_MSG_ADDON", { prefix = "robots.txt", text = "Q:CraftScan", channel = "WHISPER", playerName = NAME })
end

return function()
  local savedTimer = _G.C_Timer
  _G.C_Timer = nil

  local ok, err = pcall(function()
    -- test_hide_removes_the_friend_chat_the_whisper_opened
    do
      local state = hideState()
      whisper(state)
      assert(state.store.conversations[B] ~= nil, "test precondition: the whisper opened the friend's chat")
      craftScan(state)
      assert(state.store.conversations[B] == nil, "the chat the greeting opened goes with it")
    end

    -- test_hide_keeps_a_friend_chat_made_from_an_earlier_character_chat
    do
      local state = hideState()
      World.SeedK(state)
      whisper(state)
      craftScan(state)
      local friend = state.store.conversations[B]
      assert(friend ~= nil and state.store.conversations[K] == nil, "the chat keeps the character's earlier history")
      assert(#friend.messages == 1 and friend.messages[1].text == "earlier", "only the greeting is removed")
    end

    -- test_requests_mode_files_the_friend_chat_the_whisper_opened
    do
      local state = World.NewState(FRIEND)
      state.accountState.settings = { addonGreetings = "requests", requestsInbox = true }
      whisper(state)
      craftScan(state)
      assert(state.store.conversations[B].request == true, "the chat the greeting opened waits in Requests")
    end

    -- test_requests_mode_leaves_a_friend_chat_made_from_an_earlier_character_chat
    do
      local state = World.NewState(FRIEND)
      state.accountState.settings = { addonGreetings = "requests", requestsInbox = true }
      World.SeedK(state)
      whisper(state)
      craftScan(state)
      assert(state.store.conversations[B].request ~= true, "a chat with earlier history is not moved to Requests")
    end

    -- test_hide_removes_the_friend_chat_opened_by_an_announced_greeting
    do
      local state = hideState()
      announce(state)
      whisper(state)
      assert(state.store.conversations[B] == nil, "an announced greeting leaves no empty friend's chat")
    end

    -- test_hide_of_an_announced_greeting_redraws_the_window_after_removing_the_chat
    do
      local state = hideState()
      announce(state)
      local refreshes = 0
      local friendAtLastRefresh = "never refreshed"
      state.refreshWindow = function()
        refreshes = refreshes + 1
        friendAtLastRefresh = state.store.conversations[B]
      end
      whisper(state)
      assert(refreshes > 0 and friendAtLastRefresh == nil, "the empty friend's row leaves the window at once")
    end

    -- test_hide_keeps_a_friend_chat_made_from_an_earlier_character_chat_when_announced
    do
      local state = hideState()
      World.SeedK(state)
      announce(state)
      whisper(state)
      local friend = state.store.conversations[B]
      assert(friend ~= nil and #friend.messages == 1, "the folded history stays, without the greeting")
    end

    -- test_hide_keeps_an_existing_friend_chat
    do
      local state = hideState()
      World.SeedB(state)
      whisper(state)
      craftScan(state)
      local friend = state.store.conversations[B]
      assert(friend ~= nil and #friend.messages == 0, "an existing chat stays, without the greeting")
    end
  end)

  _G.C_Timer = savedTimer
  assert(ok, err)
end
