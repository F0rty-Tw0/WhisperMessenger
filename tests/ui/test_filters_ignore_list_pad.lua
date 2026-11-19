local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local FiltersSettings = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings")
local GamepadNav = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")
local GamepadSettings = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadSettings")

local NOW = 1000000

local function create(count)
  local filters = { ignored = {}, rules = {} }
  for index = 1, count do
    local name = string.format("Player%03d", index)
    filters.ignored[string.lower(name)] = { name = name, addedAt = NOW, blocked = 0 }
  end
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  return FiltersSettings.Create(factory, parent, { filters = filters }, { onChange = function() end }), factory, parent
end

-- The real nav over the fake SmartNav, attached to the Filters page.
local function attach(result, factory, parent)
  local env = FakeGamepad.New()
  local nav = GamepadNav.New(factory.CreateFrame("Frame", nil, parent), env.deps())
  GamepadSettings.Attach(nav, { panels = { result.frame } })
  return env
end

return function()
  Localization.Configure({ language = "enUS" })
  local savedTime = rawget(_G, "time")
  rawset(_G, "time", function()
    return NOW
  end)

  -- test_dpad_past_the_last_visible_row_scrolls_the_list
  do
    local result, factory, parent = create(8) -- 6 rows show Player001..Player006
    local env = attach(result, factory, parent)
    local lastRow = FindUI.text(result.frame, "Player006").parent
    local firstRow = FindUI.text(result.frame, "Player001").parent
    assert(env.press(lastRow.removeButton, "DOWN") == "stay" and lastRow.nameText.text == "Player007", "next name scrolls in")
    assert(env.press(lastRow.removeButton, "DOWN") == "stay" and lastRow.nameText.text == "Player008", "and the last one")
    assert(env.press(lastRow.removeButton, "DOWN") == "move", "end of the list: D-pad moves on to Block for")
    assert(env.press(firstRow.removeButton, "UP") == "stay" and firstRow.nameText.text == "Player002", "up at the top row scrolls back")
  end

  -- test_short_list_lets_the_dpad_move_on
  do
    local result, factory, parent = create(6)
    local env = attach(result, factory, parent)
    local lastRow = FindUI.text(result.frame, "Player006").parent
    assert(env.press(lastRow.removeButton, "DOWN") == "move" and lastRow.nameText.text == "Player006", "nothing to scroll")
  end

  rawset(_G, "time", savedTime)
end
