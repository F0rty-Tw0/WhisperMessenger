local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local FiltersSettings = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings")
local GamepadNav = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")
local GamepadSettings = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadSettings")
local PadButtons = require("WhisperMessenger.UI.Shared.SettingsControls.PadButtons")

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

-- The pad button below `root` with this glyph atlas; errors when there is none.
local function padButton(root, atlas)
  local button = FindUI.find(root, function(node)
    local glyph = node._wmPadButton == true and FindUI.ofType(node, "Texture")[1]
    return glyph and glyph.atlas == atlas or false
  end)
  return assert(button, "no pad button with atlas " .. atlas)
end

local function listOf(result)
  return FindUI.text(result.frame, "Player001").parent.parent
end

local function titleRegion(result)
  return FindUI.text(result.frame, "Blocked players (8)")
end

local function blockForRow(result)
  return FindUI.text(result.frame, "Block for").parent
end

-- Runs fn(state) with the gamepad API installed and the pad UI toggle at
-- state.on (fn may flip it), restoring the globals afterwards.
local function withPadUI(on, fn)
  local gamepad = FakeGamepad.New()
  local state = { on = on }
  local savedInputUtil = rawget(_G, "InputUtil")
  gamepad.install()
  rawset(_G, "InputUtil", {
    IsGamepadUIEnabled = function()
      return state.on
    end,
  })
  local ok, err = pcall(fn, state)
  rawset(_G, "InputUtil", savedInputUtil)
  gamepad.uninstall()
  assert(ok, err)
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

  -- test_down_and_up_pad_buttons_scroll_one_row
  withPadUI(true, function()
    local result = create(8) -- rows show Player001..Player006
    local top = FindUI.text(result.frame, "Player001").parent
    FindUI.click(padButton(result.frame, PadButtons.ATLAS.down))
    assert(top.nameText.text == "Player002", "down: one row")
    FindUI.click(padButton(result.frame, PadButtons.ATLAS.up))
    assert(top.nameText.text == "Player001", "up: one row back")
  end)

  -- test_down_at_the_end_changes_nothing
  withPadUI(true, function()
    local result = create(8)
    local top = FindUI.text(result.frame, "Player001").parent
    local down = padButton(result.frame, PadButtons.ATLAS.down)
    for _ = 1, 3 do
      FindUI.click(down)
    end
    assert(top.nameText.text == "Player003", "stops at the max offset 2")
  end)

  -- test_pad_buttons_shown_only_with_the_pad_ui
  withPadUI(false, function(state)
    local result = create(8)
    local up, down = padButton(result.frame, PadButtons.ATLAS.up), padButton(result.frame, PadButtons.ATLAS.down)
    assert(up:IsShown() == false and down:IsShown() == false, "off: hidden")
    state.on = true
    PadButtons.Refresh()
    assert(up:IsShown() == true and down:IsShown() == true, "toggled on: shown")
  end)

  -- test_space_only_while_pad_ui_on
  withPadUI(true, function(state)
    local result = create(8)
    local list = listOf(result)
    local up, down = padButton(result.frame, PadButtons.ATLAS.up), padButton(result.frame, PadButtons.ATLAS.down)
    assert(list.point[2] == up, "on: list below the up button")
    assert(blockForRow(result).point[2] == down, "on: Block for below the down button")
    state.on = false
    PadButtons.Refresh()
    assert(list.point[2] == titleRegion(result) and list.point[5] == -8 and #list.points == 1, "off: list back under the title")
    assert(blockForRow(result).point[2] == list and #blockForRow(result).points == 1, "off: Block for back on the list")
  end)

  -- test_up_button_stays_centred_after_a_width_change
  withPadUI(true, function()
    local result = create(8)
    local up = padButton(result.frame, PadButtons.ATLAS.up)
    result.refreshLayout(300)
    local centre = (300 - PadButtons.SIZE) / 2
    assert(up.point[4] == centre and listOf(result).point[4] == -centre, "re-centred over the narrower list")
  end)

  -- test_no_gamepad_api_keeps_todays_anchors
  do
    local result = create(8)
    assert(FindUI.find(result.frame, function(node)
      return node._wmPadButton == true
    end) == nil, "no pad button without the API")
    local list = listOf(result)
    assert(list.point[2] == titleRegion(result) and list.point[5] == -8, "list under the title")
    assert(blockForRow(result).point[2] == list, "Block for on the list")
  end

  -- test_pad_buttons_install_no_jump_override
  withPadUI(true, function()
    local result, factory, parent = create(8)
    local env = attach(result, factory, parent)
    assert(env.count("AddJumpNavigationOverride") == 0, "pad buttons set no jump override")
  end)

  rawset(_G, "time", savedTime)
end
