local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")

local function noop() end

-- Fresh Whispers/Groups strip on a window; `changed` records onModeChanged.
local function build(native)
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  local changed = {}
  local toggle = TabToggle.Create(factory, window, {
    initialMode = "whispers",
    nativeChrome = native,
    windowFrame = window,
    onModeChanged = function(mode)
      changed[#changed + 1] = mode
    end,
  })
  toggle.setModes({ "whispers", "groups" })
  return toggle, changed
end

local function buttons(toggle)
  return FindUI.ofType(toggle.frame, "Button")
end

local function click(btn)
  btn.scripts.OnClick(btn)
end

return function()
  for _, native in ipairs({ false, true }) do
    local label = native and "HUD" or "modern"

    -- test_current_mode_tap_runs_the_handler_and_no_mode_event
    do
      local toggle, changed = build(native)
      local calls = 0
      toggle.setCurrentModeClickHandler(function()
        calls = calls + 1
      end)
      click(buttons(toggle)[1])
      assert(calls == 1 and #changed == 0, label .. ": current tap")
    end

    -- test_other_mode_tap_skips_the_current_handler
    do
      local toggle, changed = build(native)
      local calls = 0
      toggle.setCurrentModeClickHandler(function()
        calls = calls + 1
      end)
      click(buttons(toggle)[2])
      assert(calls == 0 and changed[1] == "groups", label .. ": other tap")
    end

    -- test_current_mode_tap_with_a_panel_selected_only_leaves_the_panel
    do
      local toggle = build(native)
      local calls = 0
      toggle.setCurrentModeClickHandler(function()
        calls = calls + 1
      end)
      toggle.addPanelTab("ca", "Alerts", noop)
      toggle.setModeClickHandler(function()
        toggle.setSelectedPanel(nil)
      end)
      toggle.setSelectedPanel("ca")
      click(buttons(toggle)[1])
      assert(calls == 0 and toggle.getSelectedPanel() == nil, label .. ": panel cleared by handler")
      toggle.setModeClickHandler(noop)
      toggle.setSelectedPanel("ca")
      click(buttons(toggle)[1])
      assert(calls == 0, label .. ": panel kept by handler")
    end

    -- test_current_mode_tap_without_a_handler_does_nothing
    do
      local bare, changed = build(native)
      click(buttons(bare)[1])
      assert(#changed == 0, label .. ": bare tap")
    end

    -- test_handler_can_be_cleared
    do
      local toggle = build(native)
      local calls = 0
      toggle.setCurrentModeClickHandler(function()
        calls = calls + 1
      end)
      click(buttons(toggle)[1])
      toggle.setCurrentModeClickHandler(nil)
      click(buttons(toggle)[1])
      assert(calls == 1, label .. ": cleared")
    end

    -- test_set_chat_view_is_gone
    do
      local toggle = build(native)
      assert(toggle.setChatView == nil, label .. ": setChatView")
    end
  end
end
