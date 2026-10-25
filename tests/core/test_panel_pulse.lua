local ExternalPreview = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ExternalPreview")
local PanelPulse = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelPulse")

local function build()
  local env = { updates = 0 }
  env.holder = ExternalPreview.New({
    now = function()
      return 1
    end,
  })
  env.onShown = PanelPulse.OnPanelShown(env.holder, function()
    env.updates = env.updates + 1
  end)
  return env
end

return function()
  -- A pulsing preview owned by "ca", whose panel then opens.
  local function ownerPanelOpened()
    local e = build()
    e.holder.set("ca", { sender = "S", text = "T", pulse = true }, false)
    e.onShown("ca")
    return e
  end

  local function test_owner_panel_opening_ends_the_pulse()
    local e = ownerPanelOpened()
    assert(e.holder.get().pulse == false, "glow off")
  end

  local function test_owner_panel_opening_refreshes_the_icons_once()
    local e = ownerPanelOpened()
    assert(e.updates == 1, "one icon refresh, got " .. e.updates)
  end

  local function test_owner_panel_opening_keeps_the_preview()
    local e = ownerPanelOpened()
    assert(e.holder.keyOf() == "ca", "preview kept")
  end

  local function test_other_panel_leaves_the_pulse()
    local e = build()
    e.holder.set("ca", { sender = "S", text = "T", pulse = true }, false)
    e.onShown("other")
    assert(e.holder.get().pulse == true and e.updates == 0, "another panel opening changes nothing")
  end

  local function test_no_preview_is_a_no_op()
    local e = build()
    e.onShown("ca")
    assert(e.updates == 0, "nothing to update without a preview")
  end

  local function test_preview_without_pulse_is_a_no_op()
    local e = build()
    e.holder.set("ca", { sender = "S", text = "T" }, false)
    e.onShown("ca")
    assert(e.updates == 0, "no armed pulse, no refresh")
  end

  test_owner_panel_opening_ends_the_pulse()
  test_owner_panel_opening_refreshes_the_icons_once()
  test_owner_panel_opening_keeps_the_preview()
  test_other_panel_leaves_the_pulse()
  test_no_preview_is_a_no_op()
  test_preview_without_pulse_is_a_no_op()
end
