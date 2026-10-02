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
    windowFrame = window,
  })
  return runtime, pane, window
end

return function()
  -- test_hud_runtime_hangs_native_tabs_below_the_window
  do
    local runtime, pane, window = makeRuntime(true)
    local tab = FindUI.ofType(runtime.tabToggle.frame, "Button")[1]
    assert(tab.template == "PanelTabButtonTemplate", "HUD runtime: native tabs")
    assert(runtime.tabToggle.frame:GetParent() == pane, "HUD runtime: tabs hide with the contacts pane")
    assert(runtime.tabToggle.frame.points[1][2] == window, "HUD runtime: tabs anchored to the window")
    assert(runtime.getContactsBottomInset() == 0, "HUD runtime: list keeps its full height")
  end

  -- test_modern_runtime_reserves_tab_bar
  do
    local runtime = makeRuntime(false)
    local tab = FindUI.ofType(runtime.tabToggle.frame, "Button")[1]
    assert(tab.template == nil, "modern runtime: custom bar")
    assert(runtime.getContactsBottomInset() == TabToggle.HEIGHT, "modern runtime: reserves the bar height")
  end
end
