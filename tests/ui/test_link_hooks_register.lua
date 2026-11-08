local LinkHooksEnv = require("tests.helpers.link_hooks_env")

-- Every composer (main window, preview quick reply) registers its input. The
-- Blizzard hooks and addon-load waits are set up by the first one only.
local function countRegistrations(env)
  local counts = { hooks = 0, addOnWaits = 0 }
  local hooksecurefunc = rawget(_G, "hooksecurefunc")
  rawset(_G, "hooksecurefunc", function(...)
    counts.hooks = counts.hooks + 1
    return hooksecurefunc(...)
  end)
  rawset(_G, "EventUtil", {
    ContinueOnAddOnLoaded = function(_name, _callback)
      counts.addOnWaits = counts.addOnWaits + 1
    end,
  })
  env.LinkHooks.RegisterInput(env.NewInput())
  return counts
end

return function()
  -- test_second_register_input_adds_no_hooks
  do
    local env = LinkHooksEnv.New()
    local counts = countRegistrations(env)
    local first = { hooks = counts.hooks, addOnWaits = counts.addOnWaits }
    assert(first.hooks > 0 and first.addOnWaits > 0, "the first input should register the hooks")
    env.LinkHooks.RegisterInput(env.NewInput())
    assert(counts.hooks == first.hooks, "a second input must not hook again, hooked " .. counts.hooks - first.hooks .. " more")
    assert(counts.addOnWaits == first.addOnWaits, "a second input must not wait for addons again")
    env.Restore()
  end

  -- test_register_input_survives_a_throwing_addon_wait
  do
    local env = LinkHooksEnv.New()
    rawset(_G, "EventUtil", {
      ContinueOnAddOnLoaded = function()
        error("unknown addon")
      end,
    })
    local input = env.NewInput()
    local ok, err = pcall(env.LinkHooks.RegisterInput, input)
    assert(ok, "RegisterInput must not throw: " .. tostring(err))
    input.focused = true
    _G.ChatFrameUtil.InsertLink("|Hitem:6948|h[Hearthstone]|h")
    assert(#env.inserts == 1, "the insert hooks should still work, got " .. #env.inserts)
    env.Restore()
  end
end
