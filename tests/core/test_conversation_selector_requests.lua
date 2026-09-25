local ConversationSelector = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ConversationSelector")

-- Opening a message request from anywhere (reply command, start whisper)
-- switches the window to the Requests tab so it is actually visible.
return function()
  local tabCalls = {}
  local tabMode = "whispers"
  local runtime = {
    accountState = { settings = { requestsInbox = true } },
    store = { conversations = { ["wow::stranger"] = { channel = "WOW", request = true }, ["wow::friend"] = { channel = "WOW" } } },
    window = {
      getTabMode = function()
        return tabMode
      end,
      setTabMode = function(mode)
        tabCalls[#tabCalls + 1] = mode
        tabMode = mode
      end,
    },
  }
  local selector = ConversationSelector.Create({
    runtime = runtime,
    markConversationRead = function() end,
    requestAvailability = function() end,
  })

  -- test_selecting_a_request_shows_the_requests_tab
  selector.selectConversation("wow::stranger")
  assert(tabCalls[1] == "requests", "switched to Requests, got " .. tostring(tabCalls[1]))
  assert(runtime.activeConversationKey == "wow::stranger", "request is the active conversation")

  -- test_already_on_requests_does_not_switch_again
  selector.selectConversation("wow::stranger")
  assert(#tabCalls == 1, "no extra tab switch")

  -- test_plain_whisper_leaves_the_tab_alone
  tabMode = "whispers"
  selector.selectConversation("wow::friend")
  assert(#tabCalls == 1, "a normal whisper does not switch tabs")

  -- test_inbox_off_never_switches
  runtime.accountState.settings.requestsInbox = false
  selector.selectConversation("wow::stranger")
  assert(#tabCalls == 1, "inbox off: requests are whispers")
end
