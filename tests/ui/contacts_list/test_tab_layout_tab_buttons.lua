local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")
local NativeTabToggle = require("WhisperMessenger.UI.ContactsList.NativeTabToggle")

local function noop() end

-- The Button labelled text under the toggle's strip: its own text (HUD
-- tab template) or a FontString child (modern tab).
local function buttonLabeled(toggle, text)
  return FindUI.find(toggle.frame, function(node)
    if node.frameType ~= "Button" then
      return false
    end
    if node.text == text then
      return true
    end
    for _, child in ipairs(FindUI.ofType(node, "FontString")) do
      if child.text == text then
        return true
      end
    end
    return false
  end)
end

local function assertModeOrder(toggle, label)
  local got = toggle.getTabButtons()
  local whispers, groups, requests = buttonLabeled(toggle, "Whispers"), buttonLabeled(toggle, "Groups"), buttonLabeled(toggle, "Requests")
  assert(whispers and groups and requests, label .. ": mode tab buttons found")
  assert(#got == 3, label .. ": three visible tabs, channels hidden")
  assert(got[1] == whispers and got[2] == groups and got[3] == requests, label .. ": TabLayout.MODES order")
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_tab_buttons_are_the_visible_mode_tabs_in_order
  do
    local toggle = TabToggle.Create(FakeUI.NewFactory(), FakeUI.NewFactory().CreateFrame("Frame", nil, nil), {})
    toggle.setModes({ "whispers", "groups", "requests" })
    assertModeOrder(toggle, "modern")
  end

  -- test_a_panel_tab_comes_last_and_leaves_when_hidden
  do
    local toggle = TabToggle.Create(FakeUI.NewFactory(), FakeUI.NewFactory().CreateFrame("Frame", nil, nil), {})
    toggle.setModes({ "whispers", "groups", "requests" })
    toggle.addPanelTab("ca", "Alerts", noop)
    local got = toggle.getTabButtons()
    assert(#got == 4 and got[4] == buttonLabeled(toggle, "Alerts"), "panel tab after the mode tabs")
    toggle.setPanelTabShown("ca", false)
    got = toggle.getTabButtons()
    assert(#got == 3 and got[3] == buttonLabeled(toggle, "Requests"), "hidden panel tab is gone")
  end

  -- test_native_tab_buttons_are_the_visible_mode_tabs_in_order
  do
    local factory = FakeUI.NewFactory()
    local toggle = NativeTabToggle.Create(factory, factory.CreateFrame("Frame", nil, nil), {})
    if toggle ~= nil then
      toggle.setModes({ "whispers", "groups", "requests" })
      assertModeOrder(toggle, "native")
    end
  end
end
