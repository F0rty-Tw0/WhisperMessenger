-- Regression: pressing the reply keybind (R) focuses the composer EditBox,
-- which causes WoW to route OnChar("r") to it. C_Timer.After(0) callbacks
-- fire at the START of the next frame, before WoW's input phase (OnChar).
-- The scrub must be deferred a second time so it runs on frame N+2, after
-- the char has already been inserted during frame N+1's input phase.

local ReplyToLast = require("WhisperMessenger.Core.SlashCommands.ReplyToLast")

return function()
  local savedCTimer = _G.C_Timer

  -- test_scrub_clears_leaked_r_char_that_arrives_after_first_deferred_callback

  do
    local timerCallbacks = {}
    rawset(_G, "C_Timer", {
      After = function(_, fn)
        table.insert(timerCallbacks, fn)
      end,
    })

    local inputText = ""
    local window = {
      setTabMode = function() end,
      composer = {
        input = {
          SetFocus = function() end,
          GetText = function()
            return inputText
          end,
          SetText = function(_, t)
            inputText = t
          end,
        },
      },
    }

    local runtime = {
      window = window,
      autoOpenHooks = nil,
      lastIncomingWhisperKey = "me::WOW::jaina",
      store = { conversations = {} },
      ensureWindow = function() end,
      setWindowVisible = function() end,
      toggle = function() end,
    }

    local windowRuntime = {
      selectConversation = function() end,
    }

    local replyFn = ReplyToLast.Create({ runtime = runtime, windowRuntime = windowRuntime })
    replyFn()

    -- Frame N+1: fire first batch of deferred callbacks.
    -- "r" has NOT been inserted yet — OnChar fires later in this frame.
    local firstBatch = timerCallbacks
    timerCallbacks = {}
    for _, cb in ipairs(firstBatch) do
      cb()
    end

    -- Simulate WoW's OnChar("r") firing during frame N+1's input phase,
    -- AFTER the C_Timer.After(0) callbacks above.
    inputText = "r"

    -- Frame N+2: fire callbacks registered inside the first batch.
    local secondBatch = timerCallbacks
    timerCallbacks = {}
    for _, cb in ipairs(secondBatch) do
      cb()
    end

    assert(inputText == "", "scrub must clear 'r' even when the char arrives after the first deferred callback; got: " .. tostring(inputText))
  end

  _G.C_Timer = savedCTimer
end
