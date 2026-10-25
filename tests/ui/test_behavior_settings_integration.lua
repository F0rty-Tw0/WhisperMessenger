-- The Behavior page's Allow addon integration toggle.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")

local LABEL = "Allow addon integration"

local function build(config)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = BehaviorSettings.Create(factory, parent, config, {
    onChange = function(key, value)
      changes[#changes + 1] = { key = key, value = value }
    end,
  })
  return result, changes
end

local function changesFor(changes, key)
  local found = {}
  for _, change in ipairs(changes) do
    if change.key == key then
      found[#found + 1] = change.value
    end
  end
  return found
end

return function()
  -- test_toggle_is_on_when_the_setting_is_unset
  do
    local result = build({})
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, LABEL)) == true, "unset means allowed")
  end

  -- test_clicking_the_toggle_reports_the_new_value
  do
    local result, changes = build({})
    FindUI.click(FindUI.toggle(result.frame, LABEL))
    local values = changesFor(changes, "allowAddonIntegration")
    assert(#values == 1 and values[1] == false, "click turns it off, got " .. tostring(values[1]))
  end

  -- test_setter_shows_a_value_without_reporting_a_change
  do
    local result, changes = build({ allowAddonIntegration = false })
    result.setAllowAddonIntegration(true)
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, LABEL)) == true, "setter turns the toggle on")
    assert(#changes == 0, "setter reports nothing")
  end

  -- test_reset_to_defaults_asks_for_integration_on_through_the_setting
  -- The handler then shows the reload popup, like a click would.
  do
    local result, changes = build({ allowAddonIntegration = false })
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    local values = changesFor(changes, "allowAddonIntegration")
    assert(#values == 1 and values[1] == true, "reset asks for the default, got " .. tostring(values[1]))
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, LABEL)) == true, "toggle shows the default")
  end
end
