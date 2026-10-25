local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local ContactsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRuntime")

local function makeRuntime(nativeChrome)
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  local pane = factory.CreateFrame("Frame", nil, window)
  pane:SetSize(200, 400)
  pane:SetFrameLevel(7)
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
    local runtime, _, window = makeRuntime(true)
    local tab = FindUI.ofType(runtime.tabToggle.frame, "Button")[1]
    assert(tab.template == "PanelTabButtonTemplate", "HUD runtime: native tabs")
    assert(runtime.tabToggle.frame:GetParent() == window, "HUD runtime: strip is the window's child, so it stays up beside a panel")
    assert(runtime.tabToggle.frame:GetFrameLevel() == 8, "HUD runtime: strip one level above the contacts pane")
    assert(runtime.tabToggle.frame.points[1][2] == window, "HUD runtime: tabs anchored to the window")
  end

  -- test_modern_runtime_hangs_its_tabs_below_the_window_too
  do
    local runtime, _, window = makeRuntime(false)
    local tab = FindUI.ofType(runtime.tabToggle.frame, "Button")[1]
    assert(tab.template == nil, "modern runtime: custom tabs")
    assert(runtime.tabToggle.frame:GetParent() == window, "modern runtime: strip is the window's child")
    assert(runtime.tabToggle.frame:GetFrameLevel() == 8, "modern runtime: strip one level above the contacts pane")
    assert(runtime.tabToggle.frame.points[1][2] == window, "modern runtime: tabs anchored to the window")
    assert(runtime.getContactsBottomInset == nil, "no list height is reserved for tabs")
  end
end
