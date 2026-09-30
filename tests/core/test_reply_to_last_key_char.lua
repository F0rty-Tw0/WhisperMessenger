-- Regression: the reply key (R) fires /wr on key-down, and the key's
-- character event reaches whatever has focus during the next frame's input
-- phase, after that frame's C_Timer callbacks. If the composer has focus by
-- then, the "r" is typed into it (appended to any saved draft).

local ReplyToLast = require("WhisperMessenger.Core.SlashCommands.ReplyToLast")

local LOW_FPS_FRAME_SECONDS = 0.1

return function()
  local savedCTimer = _G.C_Timer

  local function makeClock()
    local clock = { now = 0, pending = {} }

    rawset(_G, "C_Timer", {
      After = function(seconds, fn)
        table.insert(clock.pending, { due = clock.now + seconds, fn = fn })
      end,
    })

    -- Callbacks scheduled while a frame's timers run wait for a later frame.
    function clock.frame(onInputPhase)
      clock.now = clock.now + LOW_FPS_FRAME_SECONDS
      local due, waiting = {}, {}
      for _, entry in ipairs(clock.pending) do
        table.insert(entry.due <= clock.now and due or waiting, entry)
      end
      clock.pending = waiting
      for _, entry in ipairs(due) do
        entry.fn()
      end
      if onInputPhase then
        onInputPhase()
      end
    end

    return clock
  end

  local function makeRuntime(input, autoOpenHooks)
    return {
      window = {
        setTabMode = function() end,
        composer = { input = input },
      },
      autoOpenHooks = autoOpenHooks,
      lastIncomingWhisperKey = "me::WOW::jaina",
      store = { conversations = {} },
      ensureWindow = function() end,
      setWindowVisible = function() end,
      toggle = function() end,
    }
  end

  local function makeInput(draft)
    local input = { text = draft, focused = false }
    function input.SetFocus()
      input.focused = true
    end
    function input.GetText()
      return input.text
    end
    function input.SetText(_, text)
      input.text = text
    end
    return input
  end

  local function pressReplyKey(runtime, input, clock)
    local replyFn = ReplyToLast.Create({
      runtime = runtime,
      windowRuntime = { selectConversation = function() end },
    })
    replyFn()
    clock.frame(function()
      if input.focused then
        input.text = input.text .. "r"
      end
    end)
    for _ = 1, 5 do
      clock.frame()
    end
  end

  -- test_reply_key_char_does_not_reach_composer_on_fallback_path
  do
    local clock = makeClock()
    local input = makeInput("hello")

    pressReplyKey(makeRuntime(input, nil), input, clock)

    assert(input.text == "hello", "reply key char must not reach the composer, got: " .. tostring(input.text))
    assert(input.focused, "reply must still focus the composer once the key press is done")
  end

  -- test_reply_key_char_does_not_reach_composer_when_auto_open_hooks_focus
  do
    local clock = makeClock()
    local input = makeInput("hello")
    local hooks = {
      onReplyTell = function()
        input:SetFocus()
        return true
      end,
    }

    pressReplyKey(makeRuntime(input, hooks), input, clock)

    assert(input.text == "hello", "reply key char must not reach the composer, got: " .. tostring(input.text))
    assert(input.focused, "reply must still focus the composer once the key press is done")
  end

  _G.C_Timer = savedCTimer
end
