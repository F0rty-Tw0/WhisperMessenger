local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local Theme = require("WhisperMessenger.UI.Theme")
local SettingsControls = require("WhisperMessenger.UI.Shared.SettingsControls")
local AppearanceSettings = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")
local SettingsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsRuntime")
local GamepadNav = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")
local GamepadSettings = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadSettings")

local function fakeNav()
  ---@type table<string, any>
  local nav = { seen = {} }
  for _, name in ipairs({ "markFocusable", "setStepper", "setEdgeOverride", "setScrollFrame", "refresh" }) do
    nav[name] = function(...)
      table.insert(nav.seen, { name = name, args = { ... } })
    end
  end
  function nav.countFor(name, widget)
    local n = 0
    for _, s in ipairs(nav.seen) do
      n = n + ((s.name == name and s.args[1] == widget) and 1 or 0)
    end
    return n
  end
  return nav
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_pad_step_moves_one_step_and_saves
  do
    local changes = {}
    local row = SettingsControls.CreateSliderRow(factory, parent, {
      label = "N",
      min = 0,
      max = 10,
      step = 1,
      initial = 9,
      onChange = function(v)
        changes[#changes + 1] = v
      end,
    })
    row.slider._wmPadStep(1)
    assert(row.slider:GetValue() == 10 and changes[1] == 10 and row.value.text == "10", "one step right, saved, label")
    row.slider._wmPadStep(1)
    assert(#changes == 1 and row.slider:GetValue() == 10, "at max: nothing changes")
    row.slider._wmPadStep(-1)
    assert(changes[2] == 9, "one step left")
  end

  -- test_window_scale_pad_step_saves_like_a_mouse_drag
  do
    local dragged, padded = {}, {}
    local dragPage = AppearanceSettings.Create(factory, parent, { windowScale = 1.0 }, {
      onChange = function(k, v)
        dragged[k] = v
      end,
    })
    local padPage = AppearanceSettings.Create(factory, parent, { windowScale = 1.0 }, {
      onChange = function(k, v)
        padded[k] = v
      end,
    })
    local drag = FindUI.slider(dragPage.frame, "Window Scale")
    drag:GetScript("OnMouseDown")(drag, "LeftButton")
    drag:SetValue(1.05, true)
    drag:GetScript("OnMouseUp")(drag, "LeftButton")
    local pad = FindUI.slider(padPage.frame, "Window Scale")
    pad._wmPadStep(1)
    assert(dragged.windowScale ~= nil and padded.windowScale == dragged.windowScale, "same key, same saved value as a drag")
    assert(FindUI.text(padPage.frame, "105%") ~= nil, "label formatted as the drag shows it")
  end

  -- test_every_settings_slider_becomes_a_focusable_stepper
  do
    local created, nav = {}, fakeNav()
    local original = SettingsControls.CreateSliderRow
    SettingsControls.CreateSliderRow = function(...)
      local row = original(...)
      created[#created + 1] = row
      return row
    end
    local ok, err = pcall(function()
      local runtime = SettingsRuntime.Create(factory, { parent = parent, theme = Theme })
      for index = 1, 9 do
        runtime.getPanel(index)
      end
      -- 9 = CreateSliderRow call sites: General 2, Appearance 4, Icons 2, Icons/UnreadRows 1 (all unconditional)
      assert(#created == 9, "every settings slider built")
      GamepadSettings.Attach(nav, { panels = runtime.settingsPanels })
    end)
    SettingsControls.CreateSliderRow = original
    assert(ok, err)
    for _, row in ipairs(created) do
      assert(nav.countFor("markFocusable", row.slider) == 1 and nav.countFor("setStepper", row.slider) == 1, "slider marked once and steps")
    end
  end

  -- test_pad_right_on_a_slider_at_max_stays_and_changes_nothing
  do
    local env = FakeGamepad.New()
    local nav = GamepadNav.New(factory.CreateFrame("Frame", nil, parent), env.deps())
    local changes = 0
    local page = factory.CreateFrame("Frame", nil, parent)
    local row = SettingsControls.CreateSliderRow(factory, page, {
      label = "N",
      min = 0,
      max = 2,
      step = 1,
      initial = 1,
      onChange = function()
        changes = changes + 1
      end,
    })
    GamepadSettings.Attach(nav, { panels = { page } })
    assert(env.press(row.slider, "RIGHT") == "stay" and row.slider:GetValue() == 2 and changes == 1, "right steps, focus stays")
    assert(env.press(row.slider, "RIGHT") == "stay" and changes == 1, "at max: stays, no change")
    assert(env.press(row.slider, "DOWN") == "move", "down leaves the slider")
  end
end
