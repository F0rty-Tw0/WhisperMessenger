local StartConversation = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.StartConversation")

-- The Start New Whisper dialog passes an askWho callback; it runs for the
-- resolved key before the tab or selection changes. Callers that pass none
-- (PublicApi.OpenConversation) ask nothing.

local function makeRuntime()
  return {
    localProfileId = "Player-1234",
    store = { conversations = {} },
    now = function()
      return 1000
    end,
  }
end

-- Builds startConversation with window and selection spies that append to one
-- order list.
local function buildOrdered(runtime, order)
  return StartConversation.Create({
    runtime = runtime,
    getWindow = function()
      return {
        setTabMode = function(mode)
          order[#order + 1] = "tab:" .. mode
        end,
      }
    end,
    selectConversation = function(key)
      order[#order + 1] = "select:" .. key
    end,
  }).startConversation
end

return function()
  -- test_start_existing_name_asks_before_select
  do
    local runtime = makeRuntime()
    local existingKey = "Player-1234::JainaProudmoore"
    runtime.store.conversations[existingKey] = { displayName = "Jaina", channel = "WOW", conversationKey = existingKey, messages = {} }
    local order = {}
    local startConversation = buildOrdered(runtime, order)

    local started = startConversation("Jaina", function(key)
      order[#order + 1] = "ask:" .. key
    end)
    assert(started == true)
    assert(order[1] == "ask:" .. existingKey and order[2] == "tab:whispers" and order[3] == "select:" .. existingKey, table.concat(order, ","))
  end

  -- test_start_new_name_asks_after_conversation_exists
  do
    local runtime = makeRuntime()
    local order = {}
    local channelAtAsk = nil
    local askedKey = nil
    local startConversation = buildOrdered(runtime, order)

    startConversation("Thrall", function(key)
      askedKey = key
      channelAtAsk = runtime.store.conversations[key] and runtime.store.conversations[key].channel
      order[#order + 1] = "ask"
    end)
    assert(channelAtAsk == "WOW", "the conversation exists as a WOW whisper when asked")
    assert(order[1] == "ask" and order[3] == "select:" .. askedKey, table.concat(order, ","))
  end

  -- test_start_without_ask_callback_asks_nothing
  do
    local runtime = makeRuntime()
    local order = {}
    local startConversation = buildOrdered(runtime, order)

    assert(startConversation("Jaina") == true, "starts without an ask callback")
    assert(#order == 2 and order[2]:sub(1, 7) == "select:", "selects, nothing else: " .. table.concat(order, ","))
  end

  -- test_start_rejected_name_asks_nothing
  do
    local asked = 0
    local startConversation = buildOrdered(makeRuntime(), {})

    local started = startConversation("   ", function()
      asked = asked + 1
    end)
    assert(started == false)
    assert(asked == 0, "a rejected name asks nothing")
  end
end
