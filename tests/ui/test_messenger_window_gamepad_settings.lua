local FakeUI = require("tests.helpers.fake_ui")
local GamepadSettings = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadSettings")

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
end
