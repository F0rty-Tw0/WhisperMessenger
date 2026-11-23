local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local Theme = require("WhisperMessenger.UI.Theme")
local SettingsControls = require("WhisperMessenger.UI.Shared.SettingsControls")
local AppearanceSettings = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")
local SettingsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsRuntime")
local GamepadSettings = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadSettings")
local PadButtons = require("WhisperMessenger.UI.Shared.SettingsControls.PadButtons")
local FakeGamepad = require("tests.helpers.fake_gamepad")

local WIDTH = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
local INSET = PadButtons.SIZE + PadButtons.GAP

-- The pad button of the slider row with this glyph atlas, or nil.
local function padButton(row, atlas)
  for _, child in ipairs(row.row.children or {}) do
    local glyph = child._wmPadButton == true and FindUI.ofType(child, "Texture")[1]
    if glyph and glyph.atlas == atlas then
      return child
    end
  end
  return nil
end

local function sliderX(row)
  return row.slider.point[4]
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

local function fakeNav()
  ---@type table<string, any>
  local nav = { seen = {} }
  for _, name in ipairs({ "markFocusable", "ignore", "setScrollFrame", "refresh" }) do
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

  local changes = {}
  local function newRow(initial)
    changes = {}
    return SettingsControls.CreateSliderRow(factory, parent, {
      label = "N",
      min = 0,
      max = 10,
      step = 1,
      initial = initial,
      onChange = function(v)
        changes[#changes + 1] = v
      end,
    })
  end

  -- test_slider_row_minus_and_plus_step_one_value
  withPadUI(true, function()
    local row = newRow(5)
    FindUI.click(padButton(row, PadButtons.ATLAS.plus))
    assert(row.slider:GetValue() == 6 and changes[1] == 6, "plus: one step up, saved")
    FindUI.click(padButton(row, PadButtons.ATLAS.minus))
    assert(row.slider:GetValue() == 5 and changes[2] == 5, "minus: one step down, saved")
  end)

  -- test_plus_at_max_changes_nothing
  withPadUI(true, function()
    local row = newRow(10)
    FindUI.click(padButton(row, PadButtons.ATLAS.plus))
    assert(#changes == 0 and row.slider:GetValue() == 10, "at max: nothing changes")
  end)

  -- test_inset_only_while_the_pad_ui_is_on
  withPadUI(true, function()
    local row = newRow(5)
    assert(padButton(row, PadButtons.ATLAS.minus):IsShown() and padButton(row, PadButtons.ATLAS.plus):IsShown(), "on: buttons shown")
    assert(sliderX(row) == INSET and row.slider:GetWidth() == WIDTH - 2 * INSET, "on: space reserved")
  end)
  withPadUI(false, function()
    local row = newRow(5)
    assert(not padButton(row, PadButtons.ATLAS.minus):IsShown() and not padButton(row, PadButtons.ATLAS.plus):IsShown(), "off: buttons hidden")
    assert(sliderX(row) == 0 and row.slider:GetWidth() == WIDTH, "off: full layout")
    assert(#row.slider.points == 1, "one anchor, never stacked")
  end)

  -- test_toggle_relayouts_the_slider
  withPadUI(true, function(state)
    local row = newRow(5)
    state.on = false
    PadButtons.Refresh()
    assert(sliderX(row) == 0 and row.slider:GetWidth() == WIDTH, "toggled off: full width")
    state.on = true
    PadButtons.Refresh()
    assert(sliderX(row) == INSET and row.slider:GetWidth() == WIDTH - 2 * INSET, "toggled on: inset back")
    assert(#changes == 0, "a re-layout saves nothing")
  end)

  -- test_set_width_keeps_the_current_inset
  withPadUI(true, function(state)
    local row = newRow(5)
    row.setWidth(400)
    assert(row.slider:GetWidth() == 400 - 2 * INSET and sliderX(row) == INSET, "on: inset kept")
    state.on = false
    PadButtons.Refresh()
    row.setWidth(400)
    assert(row.slider:GetWidth() == 400 and sliderX(row) == 0, "off: full width")
    state.on = true
    PadButtons.Refresh()
    assert(row.slider:GetWidth() == 400 - 2 * INSET, "toggle on after setWidth uses the new row width")
  end)

  -- test_no_gamepad_api_no_pad_buttons_full_width
  do
    local row = newRow(5)
    for _, child in ipairs(row.row.children or {}) do
      assert(child._wmPadButton == nil, "no pad button without the API")
    end
    assert(row.slider:GetWidth() == WIDTH and sliderX(row) == 0, "full width")
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

  -- test_every_settings_slider_is_skipped_by_the_pad_cursor
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
      assert(nav.countFor("ignore", row.slider) == 1, "slider skipped once")
      assert(nav.countFor("markFocusable", row.slider) == 0, "slider is not a D-pad stop")
    end
  end
end
