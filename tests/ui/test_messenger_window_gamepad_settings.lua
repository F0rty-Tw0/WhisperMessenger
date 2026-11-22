local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local FindUI = require("tests.helpers.find_ui")
local MenuPopupWorld = require("tests.helpers.menu_popup_world")
local Localization = require("WhisperMessenger.Locale.Localization")
local Theme = require("WhisperMessenger.UI.Theme")
local MenuPopup = require("WhisperMessenger.UI.Shared.MenuPopup")
local SettingsControls = require("WhisperMessenger.UI.Shared.SettingsControls")
local PadButtons = require("WhisperMessenger.UI.Shared.SettingsControls.PadButtons")
local GamepadSettings = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadSettings")

local TOGGLE_EVENT = "INPUT_DEVICE_INTERFACE_TRANSITION"

-- The pad button of the slider row with this glyph atlas; errors when none.
local function padButton(row, atlas)
  for _, child in ipairs(row.row.children or {}) do
    local glyph = child._wmPadButton == true and FindUI.ofType(child, "Texture")[1]
    if glyph and glyph.atlas == atlas then
      return child
    end
  end
  error("no pad button with atlas " .. atlas)
end

local function padShown(row)
  return padButton(row, PadButtons.ATLAS.minus):IsShown() and padButton(row, PadButtons.ATLAS.plus):IsShown()
end

-- Runs fn(env, state) with the gamepad API installed and the pad UI toggle
-- at state.on (fn may flip it), restoring the globals afterwards.
local function withPadUI(on, fn)
  local env = FakeGamepad.New()
  local state = { on = on }
  local savedInputUtil = rawget(_G, "InputUtil")
  env.install()
  rawset(_G, "InputUtil", {
    IsGamepadUIEnabled = function()
      return state.on
    end,
  })
  local ok, err = pcall(fn, env, state)
  rawset(_G, "InputUtil", savedInputUtil)
  env.uninstall()
  assert(ok, err)
end

local function fakeNav()
  ---@type table<string, any>
  local nav = { seen = {} }
  for _, name in ipairs({ "markFocusable", "setScrollFrame", "refresh" }) do
    nav[name] = function(...)
      table.insert(nav.seen, { name = name, args = { ... } })
    end
  end
  function nav.count(name)
    local n = 0
    for _, s in ipairs(nav.seen) do
      n = n + (s.name == name and 1 or 0)
    end
    return n
  end
  function nav.last(name)
    local found
    for _, s in ipairs(nav.seen) do
      if s.name == name then
        found = s.args
      end
    end
    return found
  end
  return nav
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  local function fakeSettings()
    return {
      contentScrollView = { scrollFrame = factory.CreateFrame("ScrollFrame", nil, parent) },
      chatScrollFrame = factory.CreateFrame("ScrollFrame", nil, parent),
      optionsPanel = factory.CreateFrame("Frame", nil, parent),
      panels = { false },
    }
  end

  -- test_right_stick_follows_the_settings_pane
  do
    local nav, s = fakeNav(), fakeSettings()
    GamepadSettings.Attach(nav, s)
    assert(nav.last("setScrollFrame")[1] == s.chatScrollFrame, "settings hidden: chat")
    s.optionsPanel:Show()
    assert(nav.last("setScrollFrame")[1] == s.contentScrollView.scrollFrame, "settings shown: page")
    s.optionsPanel:Hide()
    assert(nav.last("setScrollFrame")[1] == s.chatScrollFrame, "settings closed: chat again")
  end

  -- test_targets_changed_rescans_once_per_call
  do
    local nav, s = fakeNav(), fakeSettings()
    local onTargetsChanged = GamepadSettings.Attach(nav, s)
    onTargetsChanged()
    assert(nav.count("refresh") == 1, "one refresh per call")
  end

  -- test_lazy_page_is_scanned_and_earlier_widgets_are_not_marked_again
  do
    local nav, s = fakeNav(), fakeSettings()
    local pageA = factory.CreateFrame("Frame", nil, parent)
    local sliderA = factory.CreateFrame("Slider", nil, factory.CreateFrame("Frame", nil, pageA))
    sliderA._wmPadStep = function() end
    ---@type any[]
    local panels = { pageA, false }
    s.panels = panels
    local onTargetsChanged = GamepadSettings.Attach(nav, s)
    assert(nav.count("markFocusable") == 1 and nav.last("markFocusable")[1] == sliderA, "built page scanned at attach")
    local pageB = factory.CreateFrame("Frame", nil, parent)
    local sliderB = factory.CreateFrame("Slider", nil, pageB)
    sliderB._wmPadStep = function() end
    panels[2] = pageB
    onTargetsChanged()
    assert(nav.count("markFocusable") == 2 and nav.last("markFocusable")[1] == sliderB, "lazy page marked, page A not again")
  end

  -- test_widget_tagged_after_its_first_scan_is_handed_over
  do
    local nav, s = fakeNav(), fakeSettings()
    local page = factory.CreateFrame("Frame", nil, parent)
    local slider = factory.CreateFrame("Slider", nil, page)
    s.panels = { page }
    local onTargetsChanged = GamepadSettings.Attach(nav, s)
    assert(nav.count("markFocusable") == 0, "untagged: nothing to hand over yet")
    slider._wmPadStep = function() end
    onTargetsChanged()
    assert(nav.count("markFocusable") == 1 and nav.last("markFocusable")[1] == slider, "tagged later: handed over on the next scan")
  end

  -- test_pad_buttons_are_marked_focusable_once
  do
    local nav, s = fakeNav(), fakeSettings()
    local page = factory.CreateFrame("Frame", nil, parent)
    local button = factory.CreateFrame("Button", nil, page)
    button._wmPadButton = true
    s.panels = { page }
    local onTargetsChanged = GamepadSettings.Attach(nav, s)
    onTargetsChanged()
    assert(nav.count("markFocusable") == 1 and nav.last("markFocusable")[1] == button, "pad button marked once")
  end

  -- test_missing_settings_parts_do_nothing
  do
    local nav = fakeNav()
    local onTargetsChanged = GamepadSettings.Attach(nav, {})
    onTargetsChanged()
    assert(nav.count("setScrollFrame") == 0 and nav.count("refresh") == 1, "no panes: only the re-scan")
  end

  Localization.Configure({ language = "enUS" })
  local sliderSpec = { label = "N", min = 0, max = 10, step = 1, initial = 5, onChange = function() end }

  -- test_pad_ui_toggled_off_hides_pad_buttons_and_frees_the_space
  withPadUI(true, function(env, state)
    local nav, s = fakeNav(), fakeSettings()
    local page = factory.CreateFrame("Frame", nil, parent)
    local row = SettingsControls.CreateSliderRow(factory, page, sliderSpec)
    s.panels, s.createFrame = { page }, env.createFrame
    GamepadSettings.Attach(nav, s)
    state.on = false
    env.fire(TOGGLE_EVENT)
    assert(not padButton(row, PadButtons.ATLAS.plus):IsShown() and not padButton(row, PadButtons.ATLAS.minus):IsShown(), "hidden at once")
    assert(row.slider.point[4] == 0 and row.slider:GetWidth() == Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, "space freed at once")
    assert(nav.count("refresh") == 1, "re-scan after the toggle (row geometry changed)")
  end)

  -- test_pad_ui_toggled_on_shows_them
  withPadUI(false, function(env, state)
    local nav, s = fakeNav(), fakeSettings()
    local page = factory.CreateFrame("Frame", nil, parent)
    local row = SettingsControls.CreateSliderRow(factory, page, sliderSpec)
    s.panels, s.createFrame = { page }, env.createFrame
    GamepadSettings.Attach(nav, s)
    assert(not padShown(row), "off before the toggle")
    state.on = true
    env.fire(TOGGLE_EVENT)
    assert(padShown(row), "shown at once")
  end)

  -- test_toggle_closes_an_open_menu_popup
  withPadUI(true, function(env, state)
    MenuPopupWorld.With(function(_worldFactory, anchor)
      local s = fakeSettings()
      s.createFrame = env.createFrame
      GamepadSettings.Attach(fakeNav(), s)
      MenuPopup.Open(anchor, function(root)
        root:CreateButton("X", function() end)
      end)
      assert(MenuPopup.IsShown() == true, "popup open before the toggle")
      state.on = false
      env.fire(TOGGLE_EVENT)
      assert(MenuPopup.IsShown() == false, "toggle closes the popup")
    end)
  end)

  -- test_settings_shown_refreshes_pad_buttons
  withPadUI(true, function(_env, state)
    local s = fakeSettings()
    local page = factory.CreateFrame("Frame", nil, parent)
    local row = SettingsControls.CreateSliderRow(factory, page, sliderSpec)
    s.panels = { page }
    GamepadSettings.Attach(fakeNav(), s)
    state.on = false
    s.optionsPanel:Show()
    assert(not padShown(row), "settings shown: toggle re-read")
  end)

  -- test_attach_survives_a_missing_event
  withPadUI(true, function(_env, state)
    local nav, s = fakeNav(), fakeSettings()
    local page = factory.CreateFrame("Frame", nil, parent)
    local row = SettingsControls.CreateSliderRow(factory, page, sliderSpec)
    s.panels = { page }
    s.createFrame = function()
      return {
        RegisterEvent = function()
          error("unknown event")
        end,
        SetScript = function() end,
      }
    end
    local onTargetsChanged = GamepadSettings.Attach(nav, s)
    assert(type(onTargetsChanged) == "function", "attach still returns the re-scan")
    state.on = false
    onTargetsChanged()
    assert(not padShown(row) and nav.count("refresh") == 1, "re-scan still refreshes the pad buttons")
  end)

  -- test_attach_survives_a_failing_create_frame
  withPadUI(true, function()
    local s = fakeSettings()
    s.createFrame = function()
      error("no frames")
    end
    assert(type(GamepadSettings.Attach(fakeNav(), s)) == "function", "attach still returns the re-scan")
  end)
end
