-- Reset to Defaults and relabeling must find each toggle by its setting key,
-- not by its position in the spec list, so specs can move between pages.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")
local ToggleSpecs = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings.ToggleSpecs")

local function withReversedSpecs(fn)
  local originalBuild = ToggleSpecs.Build
  rawset(ToggleSpecs, "Build", function(...)
    local specs = originalBuild(...)
    local reversed = {}
    for i = #specs, 1, -1 do
      reversed[#reversed + 1] = specs[i]
    end
    return reversed
  end)
  local ok, err = pcall(fn)
  rawset(ToggleSpecs, "Build", originalBuild)
  assert(ok, err)
end

return function()
  -- test_reset_restores_each_toggle_by_key_when_spec_order_changes
  withReversedSpecs(function()
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local result = BehaviorSettings.Create(factory, parent, { autoFocusComposer = true, shareTypingStatus = false }, {
      onChange = function() end,
    })

    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))

    local autoFocus = FindUI.toggle(result.frame, "Auto-focus chat input")
    assert(FindUI.isToggleOn(autoFocus) == false, "reset must turn auto-focus off (its own default)")
  end)
end
