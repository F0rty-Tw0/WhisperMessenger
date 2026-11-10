-- Regression: a toggle binding on a letter key (like Shift-G) runs on key-down,
-- and the key's character event reaches whatever has focus during the next
-- frame's input phase, after that frame's C_Timer callbacks. If the toggle
-- focuses the composer right away, the letter is typed into it.

local LOW_FPS_FRAME_SECONDS = 0.1

local function load(path, ns)
  local chunk = assert(loadfile(path))
  chunk("WhisperMessenger", ns)
end

return function()
  local savedCTimer = _G.C_Timer
  local savedToggle = _G.WhisperMessenger_Toggle
  local savedBindingName = _G.BINDING_NAME_WHISPERMESSENGER_TOGGLE

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

  local function loadBindings(toggle)
    local ns = { Bootstrap = { runtime = { toggle = toggle } } }
    load("Core/KeySettle.lua", ns)
    load("Core/Bindings.lua", ns)
  end

  -- test_toggle_key_char_does_not_reach_composer
  do
    local clock = makeClock()
    local input = { text = "", focused = false }
    loadBindings(function()
      input.focused = true
    end)

    _G.WhisperMessenger_Toggle()
    -- The key's single character event lands in the first frame's input phase.
    local function typeKeyChar()
      if input.focused then
        input.text = input.text .. "G"
      end
    end
    clock.frame(typeKeyChar)
    for _ = 1, 5 do
      clock.frame()
    end

    assert(input.text == "", "key character leaked into the composer: " .. tostring(input.text))
    assert(input.focused, "toggle never ran")
  end

  -- test_toggle_runs_at_once_without_c_timer
  do
    rawset(_G, "C_Timer", nil)
    local toggles = 0
    loadBindings(function()
      toggles = toggles + 1
    end)

    _G.WhisperMessenger_Toggle()
    assert(toggles == 1, "expected toggle to run at once without C_Timer, ran " .. toggles)
  end

  rawset(_G, "C_Timer", savedCTimer)
  rawset(_G, "WhisperMessenger_Toggle", savedToggle)
  rawset(_G, "BINDING_NAME_WHISPERMESSENGER_TOGGLE", savedBindingName)
end
