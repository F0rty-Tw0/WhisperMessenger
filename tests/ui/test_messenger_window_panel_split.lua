local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")

local INSET = Theme.LAYOUT.CONTACTS_PANE_LEFT_INSET

local function build(state)
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1920, 1080)
  local window = MessengerWindow.Create(factory, { state = state })
  _G.UIParent = savedUIParent
  window.frame:Show()
  return window
end

local function registerRecorder(window)
  local splits = {}
  local ok = window.registerPanel("ca", {
    title = "Alerts",
    onShow = function() end,
    onSplit = function(_, listWidth)
      splits[#splits + 1] = listWidth
    end,
  })
  assert(ok == true, "registerPanel accepts a panel with onSplit")
  return splits
end

return function()
  -- test_window_resize_reaches_the_open_panel
  do
    local window = build({ width = 900, height = 560, contactsWidth = 260 })
    local splits = registerRecorder(window)
    window.showPanel("ca")
    assert(splits[1] == window.contactsPane:GetWidth() + INSET, "seeded from the current layout")
    local before = #splits
    window.frame:GetScript("OnSizeChanged")(window.frame, 900, 560)
    assert(#splits > before, "window resize reaches the panel")
    assert(splits[#splits] == window.contactsPane:GetWidth() + INSET, "with the live pane width")
  end

  -- test_rail_state_reports_rail_width
  do
    local window = build({ width = 900, height = 560, contactsWidth = 260, contactsCollapsed = true })
    local splits = registerRecorder(window)
    window.showPanel("ca")
    assert(splits[1] == Theme.LAYOUT.CONTACTS_RAIL_WIDTH + INSET, "collapsed: the rail's width, got " .. tostring(splits[1]))
  end
end
