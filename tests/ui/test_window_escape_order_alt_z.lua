local FakeUI = require("tests.helpers.fake_ui")
local EscapeOrder = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.EscapeOrder")

local WINDOW_NAME = "WhisperMessengerWindow"

local function contains(list, value)
  for _, item in ipairs(list or {}) do
    if item == value then
      return true
    end
  end
  return false
end

-- Runs fn(env) with a shown window under a parent that behaves like the
-- client's UIParent: showing it again (Alt+Z) runs the game's close-all
-- sweep over UISpecialFrames before any hook on it.
local function withAltZ(fn)
  local savedSpecial = _G.UISpecialFrames
  local factory = FakeUI.NewFactory()
  local env = {}
  env.parent = factory.CreateFrame("Frame", "UIParent", nil)
  env.parent:Show()
  env.window = factory.CreateFrame("Frame", WINDOW_NAME, env.parent)
  env.window:Show()
  local named = { [WINDOW_NAME] = env.window }
  _G.UISpecialFrames = {}
  env.parent:SetScript("OnShow", function()
    for _, name in ipairs(_G.UISpecialFrames) do
      local special = named[name]
      if special and special:IsShown() then
        special:Hide()
      end
    end
  end)
  env.order = EscapeOrder.New(env.window)
  local ok, err = pcall(fn, env)
  _G.UISpecialFrames = savedSpecial
  assert(ok, err)
end

-- test_alt_z_round_trip_keeps_window_open
withAltZ(function(env)
  env.order.claim()
  env.parent:Hide()
  env.parent:Show()
  assert(env.window:IsShown(), "the sweep after Alt+Z must not close the window")
  assert(contains(_G.UISpecialFrames, WINDOW_NAME), "ESC closes the window again afterwards")
end)

-- test_claim_while_ui_hidden_waits_for_the_sweep
withAltZ(function(env)
  env.order.claim()
  env.parent:Hide()
  -- The window's own OnShow (strata promote) can run before the parent's.
  env.order.claim()
  env.parent:Show()
  assert(env.window:IsShown(), "a claim while the UI is hidden must not put the window back before the sweep")
  assert(contains(_G.UISpecialFrames, WINDOW_NAME), "listed once the UI is back")
end)

-- test_alt_z_keeps_a_yielded_window_unlisted
withAltZ(function(env)
  env.parent:Hide()
  env.parent:Show()
  assert(not contains(_G.UISpecialFrames, WINDOW_NAME), "a window that had given ESC away stays off the list")
end)

print("PASS: test_window_escape_order_alt_z")
