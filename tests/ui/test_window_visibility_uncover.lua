local FakeUI = require("tests.helpers.fake_ui")
local WindowVisibility = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowVisibility")

-- onUncovered counts how often the selected chat came back on screen.
local function build()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", "Window", nil)
  frame:Show()
  local env = { uncovered = 0, closed = 0 }
  local optionsPanel = factory.CreateFrame("Frame", nil, frame)
  local panelHost = {
    show = function()
      return true
    end,
    hide = function() end,
  }
  env.v = WindowVisibility.Create({
    optionsPanel = optionsPanel,
    contactsPane = factory.CreateFrame("Frame", nil, frame),
    contentPane = factory.CreateFrame("Frame", nil, frame),
    frame = frame,
    panelHost = panelHost,
    onClose = function()
      env.closed = env.closed + 1
      if env.closeError then
        error(env.closeError, 0)
      end
    end,
    onConversationUncovered = function()
      env.uncovered = env.uncovered + 1
    end,
  })
  return env
end

return function()
  -- test_conversation_pane_shown_when_nothing_covers_it
  do
    local env = build()
    assert(env.v.isConversationPaneShown() == true, "nothing open: chat panes on screen")
  end

  -- test_conversation_pane_hidden_under_a_panel
  do
    local env = build()
    env.v.setPanelVisible("ca")
    assert(env.v.isConversationPaneShown() == false, "panel open: chat covered")
    env.v.setPanelVisible(nil)
    assert(env.v.isConversationPaneShown() == true, "panel closed: chat back")
  end

  -- test_conversation_pane_hidden_under_options
  do
    local env = build()
    env.v.setOptionsVisible(true)
    assert(env.v.isConversationPaneShown() == false, "options open: chat covered")
    env.v.setOptionsVisible(false)
    assert(env.v.isConversationPaneShown() == true, "options closed: chat back")
  end

  -- test_closing_a_panel_reports_the_chat_uncovered
  do
    local env = build()
    env.v.setPanelVisible("ca")
    assert(env.uncovered == 0, "opening a panel uncovers nothing")
    env.v.setPanelVisible(nil)
    assert(env.uncovered == 1, "panel close uncovers once, got " .. env.uncovered)
  end

  -- test_closing_options_reports_the_chat_uncovered
  do
    local env = build()
    env.v.setOptionsVisible(true)
    assert(env.uncovered == 0, "opening options uncovers nothing")
    env.v.setOptionsVisible(false)
    assert(env.uncovered == 1, "options close uncovers once, got " .. env.uncovered)
  end

  -- test_closing_with_nothing_open_reports_nothing
  do
    local env = build()
    env.v.setPanelVisible(nil)
    env.v.setOptionsVisible(false)
    assert(env.uncovered == 0, "nothing was covered, got " .. env.uncovered)
  end

  -- test_switching_between_panel_and_options_keeps_the_chat_covered
  do
    local env = build()
    env.v.setPanelVisible("ca")
    env.v.setOptionsVisible(true)
    env.v.setPanelVisible("ca")
    env.v.setPanelVisible("two")
    assert(env.uncovered == 0, "chat never came back, got " .. env.uncovered)
  end

  -- test_quiet_panel_close_reports_nothing
  do
    local env = build()
    env.v.setPanelVisible("ca")
    env.v.setPanelVisible(nil, true)
    assert(env.uncovered == 0, "quiet close is silent, got " .. env.uncovered)
    assert(env.v.isConversationPaneShown() == true, "the panel still closed")
  end

  -- test_closing_the_window_from_options_reports_nothing
  do
    local env = build()
    env.v.setOptionsVisible(true)
    env.v.closeWindow()
    assert(env.closed == 1, "window closed")
    assert(env.uncovered == 0, "closing the window is not an uncover, got " .. env.uncovered)
  end

  -- test_closing_the_window_from_a_panel_reports_nothing
  do
    local env = build()
    env.v.setPanelVisible("ca")
    env.v.closeWindow()
    assert(env.closed == 1, "window closed")
    assert(env.uncovered == 0, "closing the window is not an uncover, got " .. env.uncovered)
  end

  -- test_uncover_works_again_after_a_window_close
  do
    local env = build()
    env.v.setOptionsVisible(true)
    env.v.closeWindow()
    env.v.setPanelVisible("ca")
    env.v.setPanelVisible(nil)
    assert(env.uncovered == 1, "the close guard reset, got " .. env.uncovered)
  end

  -- test_a_throwing_close_handler_does_not_leave_the_close_guard_set
  do
    local env = build()
    env.closeError = "boom"
    env.v.setOptionsVisible(true)
    local ok, err = pcall(env.v.closeWindow)
    assert(ok == false and err == "boom", "the error still surfaces, got " .. tostring(err))
    env.v.setPanelVisible("ca")
    env.v.setPanelVisible(nil)
    assert(env.uncovered == 1, "the close guard reset after the error, got " .. env.uncovered)
  end
end
