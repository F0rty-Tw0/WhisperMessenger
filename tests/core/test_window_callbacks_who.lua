local Store = require("WhisperMessenger.Model.ConversationStore")
local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")

local KEY = "wow::WOW::jaina"

local function build()
  local runtime = { store = Store.New({ maxMessagesPerConversation = 10 }) }
  Store.EnsureConversation(runtime.store, KEY)
  local callbacks = WindowCallbacks.Create({
    runtime = runtime,
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

    -- test_whisper_send_asks_who_then_reaches_send_handler
    do
      calls = {}
      local callbacks, runtime = build()
      local result = callbacks.onSend({ channel = "WOW", conversationKey = KEY, text = "hello" })
      assert(#calls == 1 and calls[1].key == KEY and calls[1].runtime == runtime, "send asks who")
      assert(result == "handled", "send handler still runs")
    end
  end)

  WhoLookup.TryFor = original
  if not ok then
    error(err, 0)
  end
end
