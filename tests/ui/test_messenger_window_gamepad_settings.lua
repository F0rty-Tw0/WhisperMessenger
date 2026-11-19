local FakeUI = require("tests.helpers.fake_ui")
local GamepadSettings = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadSettings")

local function fakeNav()
  ---@type table<string, any>
  local nav = { seen = {} }
  for _, name in ipairs({ "markFocusable", "setStepper", "setEdgeOverride", "setScrollFrame", "refresh" }) do
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
      menuScrollView = { scrollFrame = factory.CreateFrame("ScrollFrame", nil, parent) },
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
    assert(nav.count("markFocusable") == 1 and nav.last("setStepper")[1] == sliderA, "built page scanned at attach")
    local pageB = factory.CreateFrame("Frame", nil, parent)
    local sliderB = factory.CreateFrame("Slider", nil, pageB)
    sliderB._wmPadStep = function() end
    panels[2] = pageB
    onTargetsChanged()
    assert(nav.count("markFocusable") == 2 and nav.last("markFocusable")[1] == sliderB, "lazy page marked, page A not again")
    assert(nav.count("setStepper") == 2 and nav.last("setStepper")[2] == sliderB._wmPadStep, "stepper is the widget's own step")
  end

  -- test_edge_tags_become_edge_overrides
  do
    local nav, s = fakeNav(), fakeSettings()
    local page = factory.CreateFrame("Frame", nil, parent)
    local button = factory.CreateFrame("Button", nil, page)
    local down = function()
      return true
    end
    button._wmPadEdges = { DOWN = down }
    s.panels = { page }
    GamepadSettings.Attach(nav, s)
    local args = nav.last("setEdgeOverride")
    assert(nav.count("setEdgeOverride") == 1 and args[1] == button and args[2] == "DOWN" and args[3] == down, "one edge override")
  end

  -- test_missing_settings_parts_do_nothing
  do
    local nav = fakeNav()
    local onTargetsChanged = GamepadSettings.Attach(nav, {})
    onTargetsChanged()
    assert(nav.count("setScrollFrame") == 0 and nav.count("refresh") == 1, "no panes: only the re-scan")
  end
end
