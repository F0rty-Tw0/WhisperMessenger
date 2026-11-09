local FakeUI = require("tests.helpers.fake_ui")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")
local FindUI = require("tests.helpers.find_ui")

-- "Esc closes the window" and the Double ESC row that only matters while it is on.

local ESCAPE_LABEL = "Esc closes the window"
local DOUBLE_ESCAPE_LABEL = "Double ESC to close"

local function build(config)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = BehaviorSettings.Create(factory, parent, config, {
    onChange = function(key, value)
      changes[key] = value
    end,
  })
  return result, changes
end

return function()
  -- test_escape_toggle_saves_key
  do
    local result, changes = build({})
    FindUI.click(FindUI.toggle(result.frame, ESCAPE_LABEL))
    assert(changes.escapeClosesWindow == false, "turning Esc off saves false, got " .. tostring(changes.escapeClosesWindow))
  end

  -- test_escape_toggle_starts_on_by_default
  do
    local result = build({})
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, ESCAPE_LABEL)) == true, "Esc closes the window defaults to on")
  end

  -- test_double_escape_greyed_when_escape_off
  do
    local result = build({ escapeClosesWindow = false })
    local row = FindUI.byLabel(result.frame, DOUBLE_ESCAPE_LABEL)
    assert(FindUI.disabledCover(row) ~= nil, "Double ESC is covered while Esc is off")
    assert(row.alpha < 1, "Double ESC is dimmed while Esc is off")
  end

  -- test_double_escape_enabled_while_escape_on
  do
    local result = build({})
    local row = FindUI.byLabel(result.frame, DOUBLE_ESCAPE_LABEL)
    assert(FindUI.disabledCover(row) == nil, "Double ESC stays usable while Esc is on")
  end

  -- test_double_escape_follows_the_escape_toggle
  do
    local result = build({})
    local row = FindUI.byLabel(result.frame, DOUBLE_ESCAPE_LABEL)
    FindUI.click(FindUI.toggle(result.frame, ESCAPE_LABEL))
    assert(FindUI.disabledCover(row) ~= nil, "Double ESC greys out as soon as Esc is turned off")
  end

  -- test_double_escape_keeps_its_value_while_greyed
  do
    local result = build({ escapeClosesWindow = false, doubleEscapeToClose = true })
    local switch = FindUI.toggle(result.frame, DOUBLE_ESCAPE_LABEL)
    assert(FindUI.isToggleOn(switch) == true, "Double ESC keeps its saved value while greyed")
  end

  -- test_double_escape_enabled_after_reset
  do
    local result, changes = build({ escapeClosesWindow = false })
    local row = FindUI.byLabel(result.frame, DOUBLE_ESCAPE_LABEL)
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(changes.escapeClosesWindow == true, "Reset to Defaults turns Esc back on, got " .. tostring(changes.escapeClosesWindow))
    assert(FindUI.disabledCover(row) == nil, "Double ESC is usable again after Reset to Defaults")
  end
end
