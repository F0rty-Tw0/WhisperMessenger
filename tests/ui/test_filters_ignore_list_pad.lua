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

  -- test_ignore_rows_install_no_jump_override
  do
    local result, factory, parent = create(8)
    local env = attach(result, factory, parent)
    local name = FindUI.text(result.frame, "Player006")
    assert(name ~= nil, "row shown")
    assert(env.count("AddJumpNavigationOverride") == 0, "no jump override on the rows")
    assert(name.parent.removeButton._wmPadEdges == nil, "no edge tag left")
  end

  rawset(_G, "time", savedTime)
end
