local FakeUI = require("tests.helpers.fake_ui")

local KEY = "wow::firstmoon"

local function loadAddonFromToc(addonName, ns)
  for line in io.lines("WhisperMessenger.toc") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and trimmed:sub(1, 2) ~= "##" and not trimmed:match("%.xml$") then
      local chunk = assert(loadfile(trimmed))
      chunk(addonName, ns)
    end
  end
end

-- The toggle key and the icon click ask /who for the chat they open onto,
-- inside the key press or click and before the window shows (a protected
-- SendWho is blocked once the key is deferred or the window is already up).
-- /wm keeps the plain toggle. The real runtime is booted: a stub toggle would
-- prove nothing.
local function boot()
  local factory = FakeUI.NewFactory()
  local accountState = {
    conversations = {
      [KEY] = {
        displayName = "Firstmoon",
        channel = "WOW",
        unreadCount = 1,
        lastActivityAt = os.time(),
        messages = {},
      },
    },
    contacts = {},
    pendingHydration = {},
    schemaVersion = 1,
    settings = { showPlayerLevels = true },
  }
  local characterState = {
    window = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 920, height = 580, minimized = false },
    icon = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
  }

  local ns = {}
  loadAddonFromToc("WhisperMessenger", ns)
  _G.UISpecialFrames = {}
  local runtime = ns.Bootstrap.Initialize(factory, {
    accountState = accountState,
    characterState = characterState,
    localProfileId = "current",
  })
  ns.Bootstrap.runtime = runtime
  assert(ns.DisplayName.ShowPlayerLevels() == true, "Show player levels is on")

  return ns, runtime
end

local function windowHidden(runtime)
  return runtime.window == nil or runtime.window.frame.shown ~= true
end

-- Runs action with WhoLookup.TryFor recording each ask and whether the window
-- was still hidden at that moment.
local function recordAsks(ns, runtime, action)
  local record = { asked = 0, askedKey = nil, windowHiddenAtAsk = nil }
  local original = ns.WhoLookup.TryFor
  ns.WhoLookup.TryFor = function(_runtime, key)
    record.asked = record.asked + 1
    record.askedKey = key
    record.windowHiddenAtAsk = windowHidden(runtime)
    return false
  end
  local ok, err = pcall(action, record)
  ns.WhoLookup.TryFor = original
  assert(ok, err)

  return record
end

local function clickIcon(runtime)
  local saved = rawget(_G, "IsShiftKeyDown")
  rawset(_G, "IsShiftKeyDown", function()
    return false
  end)
  local button = runtime.icon.frame
  local ok, err = pcall(button.scripts.OnClick, button, "LeftButton")
  rawset(_G, "IsShiftKeyDown", saved)
  assert(ok, err)
end

return function()
  local savedTime = rawget(_G, "time")
  rawset(_G, "time", os.time)

  -- test_toggle_key_asks_who_inside_the_key_press
  -- The key defers its toggle through C_Timer. Timers are queued, not run, so
  -- an ask that moved into the deferred callback is not counted.
  do
    local ns, runtime = boot()
    local savedCTimer = rawget(_G, "C_Timer")
    local queued = {}
    rawset(_G, "C_Timer", {
      After = function(_seconds, fn)
        queued[#queued + 1] = fn
      end,
    })
    local askedInsidePress, drained = nil, 0
    -- The timers drain inside the recorder, so an extra ask in the deferred
    -- callback is counted too.
    local record = recordAsks(ns, runtime, function(live)
      _G.WhisperMessenger_Toggle()
      askedInsidePress = live.asked
      while #queued > 0 and drained < 10 do
        table.remove(queued, 1)()
        drained = drained + 1
      end
    end)
    rawset(_G, "C_Timer", savedCTimer)
    ns.DisplayName.Configure({ showPlayerLevels = false })

    assert(askedInsidePress == 1, "the toggle key asks /who once inside the press, asked " .. askedInsidePress)
    assert(record.asked == 1, "no second ask after the key press, asked " .. record.asked)
    assert(record.askedKey == KEY)
    assert(record.windowHiddenAtAsk == true, "ask must run before the window shows")
    assert(drained > 0, "the toggle was deferred through C_Timer")
    assert(runtime.window.frame.shown == true and runtime.activeConversationKey == KEY)
  end

  -- test_toggle_key_closing_the_window_asks_nothing
  do
    local ns, runtime = boot()
    runtime.toggle()
    assert(runtime.window.frame.shown == true, "the window is open")
    local record = recordAsks(ns, runtime, _G.WhisperMessenger_Toggle)
    ns.DisplayName.Configure({ showPlayerLevels = false })

    assert(record.asked == 0, "the key closes the window and asks nothing, asked " .. record.asked)
    assert(runtime.window.frame.shown ~= true, "the key closed the window")
  end

  -- test_icon_click_asks_who_before_the_window_shows
  do
    local ns, runtime = boot()
    assert(not runtime.icon.previewFrame:IsShown(), "no preview card, so this is the plain icon path")
    local record = recordAsks(ns, runtime, function()
      clickIcon(runtime)
    end)
    ns.DisplayName.Configure({ showPlayerLevels = false })

    assert(record.asked == 1, "the icon click asks /who once, asked " .. record.asked)
    assert(record.askedKey == KEY)
    assert(record.windowHiddenAtAsk == true, "ask must run before the window shows")
    assert(runtime.window.frame.shown == true)
  end

  rawset(_G, "time", savedTime)
end
