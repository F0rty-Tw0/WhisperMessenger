local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")

-- A modern window with panel "ca"; `uncovered.count` counts every report that
-- the selected chat is back on screen.
local function build()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1280, 720)
  local uncovered = { count = 0 }
  local window = MessengerWindow.Create(factory, {
    onConversationUncovered = function()
      uncovered.count = uncovered.count + 1
    end,
  })
  _G.UIParent = savedUIParent
  window.frame:Show()
  assert(window.registerPanel("ca", { title = "ca", onShow = function() end, onHide = function() end }) == true)
  return window, uncovered
end

local function click(b)
  b:GetScript("OnClick")(b)
end

local function buttons(window)
  return FindUI.ofType(window.tabToggle.frame, "Button")
end

return function()
  -- test_window_reports_whether_the_chat_panes_are_on_screen
  do
    local window = build()
    assert(window.isConversationPaneShown() == true, "fresh window: shown")
    window.showPanel("ca")
    assert(window.isConversationPaneShown() == false, "panel covers")
    window.hidePanel()
    click(window.optionsButton)
    assert(window.isConversationPaneShown() == false, "options covers")
    click(window.backButton)
    assert(window.isConversationPaneShown() == true, "back to the chat")
  end

  -- test_back_from_options_and_hide_panel_report_the_chat_uncovered
  do
    local window, uncovered = build()
    click(window.optionsButton)
    click(window.backButton)
    assert(uncovered.count == 1, "options back, got " .. uncovered.count)
    window.showPanel("ca")
    window.hidePanel()
    assert(uncovered.count == 2, "hidePanel, got " .. uncovered.count)
    window.showPanel("ca")
    click(window.backButton)
    assert(uncovered.count == 3, "panel back, got " .. uncovered.count)
  end

  -- test_close_button_with_options_or_panel_open_reports_nothing
  do
    local window, uncovered = build()
    click(window.optionsButton)
    click(window.closeButton)
    assert(uncovered.count == 0, "close from options, got " .. uncovered.count)
    window.showPanel("ca")
    click(window.closeButton)
    assert(uncovered.count == 0, "close from a panel, got " .. uncovered.count)
  end

  -- test_hiding_the_window_with_a_panel_open_reports_nothing
  do
    local window, uncovered = build()
    window.showPanel("ca")
    window.frame:Hide()
    assert(window.getVisiblePanel() == nil, "the hide closed the panel")
    assert(uncovered.count == 0, "hide is not an uncover, got " .. uncovered.count)
  end

  -- test_mode_tab_click_reports_only_for_the_current_mode
  do
    local window, uncovered = build()
    local tabs = buttons(window)
    window.showPanel("ca")
    click(tabs[1])
    assert(uncovered.count == 1, "current mode's tab, got " .. uncovered.count)
    window.showPanel("ca")
    click(tabs[2])
    assert(window.getTabMode() == "groups", "switched to groups")
    assert(uncovered.count == 1, "another mode selects its own chat, got " .. uncovered.count)
  end
end
