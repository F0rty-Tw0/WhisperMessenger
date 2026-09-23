local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")
local ContactsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRuntime")

local function makeRuntime(nativeChrome)
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  local pane = factory.CreateFrame("Frame", nil, window)
  pane:SetSize(200, 400)
  local contactsView = ScrollView.Create(factory, pane, { width = 200, height = 400 })
  local runtime = ContactsRuntime.Create(factory, {
    contactsPane = pane,
    contactsView = contactsView,
    nativeChrome = nativeChrome,
  })
  return runtime, pane
end

return function()
  -- test_hud_runtime_builds_native_tabs_inside_pane
  do
    local runtime, pane = makeRuntime(true)
    local tab = FindUI.ofType(runtime.tabToggle.frame, "Button")[1]
    assert(tab.template == "PanelTabButtonTemplate", "HUD runtime: native tabs")
    assert(runtime.tabToggle.frame.points[1][2] == pane, "HUD runtime: tabs anchored inside the contacts pane")
    assert(runtime.getContactsBottomInset() == TabToggle.NATIVE_HEIGHT, "HUD runtime: list stops above the tabs")
  end

  -- test_modern_runtime_reserves_tab_bar
  do
    local runtime = makeRuntime(false)
    local tab = FindUI.ofType(runtime.tabToggle.frame, "Button")[1]
    assert(tab.template == nil, "modern runtime: custom bar")
    assert(runtime.getContactsBottomInset() == TabToggle.HEIGHT, "modern runtime: reserves the bar height")
  end
end
