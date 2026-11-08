local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")

local function noop() end

local function build(native, modes)
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  local toggle = TabToggle.Create(factory, window, { initialMode = "whispers", nativeChrome = native, windowFrame = window })
  toggle.setModes(modes or { "whispers", "groups" })
  return toggle
end

local function buttons(toggle)
  return FindUI.ofType(toggle.frame, "Button")
end

return function()
  for _, native in ipairs({ false, true }) do
    local label = native and "HUD" or "modern"

    -- test_hiding_a_panel_tab_hides_its_button_and_showing_brings_it_back
    do
      local toggle = build(native)
      toggle.addPanelTab("ca", "Alerts", noop)
      local btn = buttons(toggle)[5]
      toggle.setPanelTabShown("ca", false)
      assert(btn:IsShown() == false, label .. ": hidden tab button")
      toggle.setPanelTabShown("ca", true)
      assert(btn:IsShown() == true, label .. ": shown again")
    end

    -- test_hidden_panel_tab_leaves_no_gap
    do
      local toggle = build(native)
      toggle.addPanelTab("a", "Alpha", noop)
      toggle.addPanelTab("b", "Beta", noop)
      toggle.setPanelTabShown("a", false)
      local b = buttons(toggle)
      assert(b[6].points[1][2] == b[2], label .. ": Beta chains straight after Groups")
    end

    -- test_unknown_key_changes_nothing
    do
      local toggle = build(native)
      toggle.addPanelTab("ca", "Alerts", noop)
      toggle.setPanelTabShown("nope", false)
      assert(buttons(toggle)[5]:IsShown() == true, label .. ": unknown key is ignored")
    end

    -- test_strip_hides_when_the_only_panel_tab_hides_with_one_mode_tab
    do
      local toggle = build(native, { "whispers" })
      toggle.addPanelTab("ca", "Alerts", noop)
      assert(toggle.frame:IsShown() == true, label .. ": Whispers + addon tab shows the strip")
      toggle.setPanelTabShown("ca", false)
      assert(toggle.frame:IsShown() == false, label .. ": one visible tab hides the strip")
      toggle.setPanelTabShown("ca", true)
      assert(toggle.frame:IsShown() == true, label .. ": strip is back")
    end
  end
end
