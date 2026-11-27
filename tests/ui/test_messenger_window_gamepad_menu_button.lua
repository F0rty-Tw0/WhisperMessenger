local FakeGamepad = require("tests.helpers.fake_gamepad")
local GamepadMenuButton = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadMenuButton")

-- t.opened: stops whose opener ran; t.log: the listener's enable and
-- propagate calls in order; t.frames: frames created; t.listener: the last.
local function newTest(opts)
  opts = opts or {}
  local env = FakeGamepad.New()
  local t = { env = env, opened = {}, log = {}, frames = 0, own = true }
  t.stop = {
    _wmOpenMenu = function(f)
      table.insert(t.opened, f)
    end,
  }
  t.nav = {
    isActive = function()
      return opts.inactive ~= true
    end,
    currentStop = function()
      return t.stop
    end,
  }
  t.deps = {
    inCombat = env.inCombat,
    after = env.after,
    usesOwnMenus = function()
      return t.own
    end,
    createFrame = function()
      local frame = env.createFrame()
      t.frames = t.frames + 1
      t.listener = frame
      if not opts.noPadMethods then
        function frame:EnableGamePadButton(value)
          table.insert(t.log, "enable:" .. tostring(value))
        end
        function frame:SetPropagateKeyboardInput(value)
          table.insert(t.log, "propagate:" .. tostring(value))
        end
      end
      return frame
    end,
  }
  return t
end

local function attach(t)
  GamepadMenuButton.Attach(t.nav, {}, t.deps)
end

local function press(t, key)
  t.listener.scripts.OnGamePadButtonDown(t.listener, key)
end

local TURNED_ON = "propagate:true,enable:true"

-- Runs fn with _G.GAMEPAD_FACE_LEFT set to value, restored after.
local function withFaceLeft(value, fn)
  local saved = rawget(_G, "GAMEPAD_FACE_LEFT")
  rawset(_G, "GAMEPAD_FACE_LEFT", value)
  local ok, err = pcall(fn)
  rawset(_G, "GAMEPAD_FACE_LEFT", saved)
  assert(ok, err)
end

return function()
  -- test_x_opens_the_current_stops_menu
  do
    local t = newTest()
    attach(t)
    press(t, "PAD3")
    assert(#t.opened == 1 and t.opened[1] == t.stop, "X opens the stop's menu")
  end

  -- test_x_follows_the_games_key_name
  do
    local t = newTest()
    attach(t)
    withFaceLeft("PAD4", function()
      press(t, "PAD4")
      press(t, "PAD3")
    end)
    assert(#t.opened == 1, "only the game's X key opens, got " .. #t.opened)
  end

  -- test_other_buttons_do_nothing
  do
    local t = newTest()
    attach(t)
    press(t, "PAD1")
    press(t, "PAD2")
    assert(#t.opened == 0, "A and B open nothing")
  end

  -- test_x_does_nothing_with_controller_mode_off
  do
    local t = newTest()
    t.own = false
    attach(t)
    press(t, "PAD3")
    assert(#t.opened == 0, "controller mode off: no menu")
  end

  -- test_x_does_nothing_without_a_current_stop
  do
    local t = newTest()
    t.stop = nil
    attach(t)
    local ok, err = pcall(press, t, "PAD3")
    assert(ok, err)
    assert(#t.opened == 0, "no stop: no menu")
  end

  -- test_x_does_nothing_on_a_stop_without_a_menu
  do
    local t = newTest()
    attach(t)
    t.stop = {}
    local ok, err = pcall(press, t, "PAD3")
    assert(ok, err)
    assert(#t.opened == 0, "a stop without an opener: no menu")
  end

  -- test_no_listener_without_the_gamepad_ui
  do
    local t = newTest({ inactive = true })
    attach(t)
    assert(t.frames == 0, "no gamepad UI: no frame")
  end

  -- test_input_passes_on_before_the_listener_turns_on
  do
    local t = newTest()
    attach(t)
    assert(table.concat(t.log, ",") == TURNED_ON, "propagate first, got " .. table.concat(t.log, ","))
  end

  -- test_built_in_combat_turns_on_after_combat
  do
    local t = newTest()
    t.env.combat = true
    attach(t)
    assert(#t.log == 0, "nothing in combat")
    t.env.combat = false
    t.env.regen()
    assert(table.concat(t.log, ",") == TURNED_ON, "on after combat, got " .. table.concat(t.log, ","))
    assert(t.listener.events.PLAYER_REGEN_ENABLED == nil, "the regen event is dropped")
  end

  -- test_still_in_combat_at_regen_retries
  do
    local t = newTest()
    t.env.combat = true
    attach(t)
    t.env.regen()
    assert(#t.log == 0, "still in combat: nothing yet")
    t.env.combat = false
    t.env.flush()
    assert(table.concat(t.log, ",") == TURNED_ON, "on at the retry, got " .. table.concat(t.log, ","))
  end

  -- test_x_never_stops_input_passing_on
  do
    local t = newTest()
    attach(t)
    press(t, "PAD3")
    press(t, "PAD1")
    for _, entry in ipairs(t.log) do
      assert(entry ~= "propagate:false", "propagation never turns off")
    end
  end

  -- test_client_without_the_frame_methods_stays_off
  do
    local t = newTest({ noPadMethods = true })
    local ok, err = pcall(attach, t)
    assert(ok, err)
    assert(#t.log == 0, "nothing turned on")
  end
end
