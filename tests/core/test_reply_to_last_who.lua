local ReplyToLast = require("WhisperMessenger.Core.SlashCommands.ReplyToLast")
local WhoTriggers = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WhoTriggers")

-- The reply key defers its action through KeySettle (C_Timer), outside the
-- key press. The quiet /who for the reply target must run inside the press,
-- before anything is selected.

return function()
  local savedCTimer = _G.C_Timer
  local savedAskFor = WhoTriggers.AskFor

  -- Returns the handler plus the order list, the ask list and a timer runner.
  local function setup(conversations, lastIncomingWhisperKey)
    local queued = {}
    rawset(_G, "C_Timer", {
      After = function(_seconds, fn)
        queued[#queued + 1] = fn
      end,
    })

    local case = { order = {}, asks = {}, toggles = 0 }
    WhoTriggers.AskFor = function(_runtime, key)
      case.asks[#case.asks + 1] = key
      case.order[#case.order + 1] = "ask:" .. key
    end

    local runtime = {
      lastIncomingWhisperKey = lastIncomingWhisperKey,
      store = { conversations = conversations },
      ensureWindow = function() end,
      setWindowVisible = function() end,
      toggle = function()
        case.toggles = case.toggles + 1
      end,
    }
    local windowRuntime = {
      selectConversation = function(key)
        case.selected = key
        case.order[#case.order + 1] = "select:" .. key
      end,
    }
    case.handler = ReplyToLast.Create({ runtime = runtime, windowRuntime = windowRuntime })
    case.runTimers = function()
      while #queued > 0 do
        table.remove(queued, 1)()
      end
    end

    return case
  end

  -- test_reply_asks_before_the_deferred_open
  do
    local case = setup({ ["wow::jaina"] = { channel = "WOW", lastActivityAt = 1 } }, "wow::jaina")
    case.handler()
    assert(#case.asks == 1 and case.asks[1] == "wow::jaina", "asked inside the key press")
    assert(case.selected == nil, "nothing selected yet when asked")
    case.runTimers()
    assert(case.selected == "wow::jaina", "the asked chat is the one that opens")
    assert(case.order[1] == "ask:wow::jaina" and case.order[2] == "select:wow::jaina", "ask first, then select: " .. table.concat(case.order, ","))
  end

  -- test_reply_falls_back_to_newest_whisper
  do
    local case = setup({
      ["wow::old"] = { channel = "WOW", lastActivityAt = 1 },
      ["wow::new"] = { channel = "WOW", lastActivityAt = 5 },
      ["party::chatty"] = { channel = "PARTY", lastActivityAt = 9 },
    }, nil)
    case.handler()
    assert(#case.asks == 1 and case.asks[1] == "wow::new", "asked the newest whisper, not the newer party chat")
    case.runTimers()
    assert(case.selected == "wow::new", "the asked chat is the one that opens")
  end

  -- test_reply_with_no_whisper_asks_nothing
  do
    local case = setup({ ["party::chatty"] = { channel = "PARTY", lastActivityAt = 9 } }, nil)
    case.handler()
    assert(#case.asks == 0, "no whisper, no ask")
    case.runTimers()
    assert(case.selected == nil and case.toggles == 1, "falls back to the plain toggle")
  end

  WhoTriggers.AskFor = savedAskFor
  _G.C_Timer = savedCTimer
end
