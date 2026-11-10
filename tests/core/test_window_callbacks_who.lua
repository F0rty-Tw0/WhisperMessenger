local Store = require("WhisperMessenger.Model.ConversationStore")
local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")

local KEY = "wow::WOW::jaina"

local function build(startConversation)
  local runtime = { store = Store.New({ maxMessagesPerConversation = 10 }) }
  Store.EnsureConversation(runtime.store, KEY)
  local callbacks = WindowCallbacks.Create({
    runtime = runtime,
    startConversation = startConversation,
    characterState = {},
    refreshWindow = function() end,
    sendHandler = {
      HandleSend = function()
        return "handled"
      end,
    },
  })
  return callbacks, runtime
end

return function()
  local original = WhoLookup.TryFor
  local calls = {}
  WhoLookup.TryFor = function(rt, key)
    calls[#calls + 1] = { runtime = rt, key = key }
    return true
  end

  local ok, err = pcall(function()
    -- test_callbacks_expose_contact_click_that_asks_who
    do
      calls = {}
      local callbacks, runtime = build()
      assert(type(callbacks.onContactClicked) == "function", "onContactClicked exposed")
      callbacks.onContactClicked({ conversationKey = KEY })
      assert(#calls == 1 and calls[1].key == KEY and calls[1].runtime == runtime, "click asks who")
    end

    -- test_callbacks_expose_header_click_that_asks_who
    do
      calls = {}
      local callbacks, runtime = build()
      assert(type(callbacks.onHeaderClicked) == "function", "onHeaderClicked exposed")
      callbacks.onHeaderClicked(KEY)
      assert(#calls == 1 and calls[1].key == KEY and calls[1].runtime == runtime, "header click asks who")
    end

    -- test_start_conversation_passes_an_ask_that_reaches_who
    do
      calls = {}
      local seenName, askWho
      local callbacks, runtime = build(function(name, ask)
        seenName = name
        askWho = ask
        return true
      end)
      assert(callbacks.onStartConversation("Jaina") == true, "start result is returned")
      assert(seenName == "Jaina" and type(askWho) == "function", "a function is passed as the second argument")
      assert(#calls == 0, "nothing asked until the start flow calls it")
      askWho(KEY)
      assert(#calls == 1 and calls[1].key == KEY and calls[1].runtime == runtime, "the callback asks who")
    end

    -- test_whisper_send_asks_who_then_reaches_send_handler
    do
      calls = {}
      local callbacks, runtime = build()
      local result = callbacks.onSend({ channel = "WOW", conversationKey = KEY, text = "hello" })
      assert(#calls == 1 and calls[1].key == KEY and calls[1].runtime == runtime, "send asks who")
      assert(result == "handled", "send handler still runs")
    end

    -- test_callbacks_expose_who_player_that_sends_visible_who
    do
      local names = {}
      local originalVisible = WhoLookup.SendVisible
      WhoLookup.SendVisible = function(name)
        names[#names + 1] = name
        return true
      end
      local callbacks = build()
      callbacks.whoPlayer("Bob")
      WhoLookup.SendVisible = originalVisible
      assert(type(callbacks.whoPlayer) == "function", "whoPlayer exposed")
      assert(#names == 1 and names[1] == "Bob", "whoPlayer sends visible who")
    end
  end)

  WhoLookup.TryFor = original
  if not ok then
    error(err, 0)
  end
end
