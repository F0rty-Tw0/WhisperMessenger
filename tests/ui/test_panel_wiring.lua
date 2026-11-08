local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local PanelWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PanelWiring")

local function noop() end

-- noTabToggle: build without a tab strip (no contacts pane).
local function build(noTabToggle, onPanelShown, onConversationUncovered)
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", "Window", nil)
  frame:Show()
  local env = { frame = frame, optionsShown = {}, railSeen = {}, covers = {} }
  local layout = {
    optionsPanel = factory.CreateFrame("Frame", nil, frame),
    contactsPane = factory.CreateFrame("Frame", nil, frame),
    contentPane = factory.CreateFrame("Frame", nil, frame),
  }
  local chrome = {
    setBackVisible = noop,
    setOptionsActive = noop,
  }
  local rail = {
    setOptionsVisible = function(visible)
      env.railSeen[#env.railSeen + 1] = visible
    end,
  }
  local tabToggle = {
    setOptionsShown = function(visible)
      env.optionsShown[#env.optionsShown + 1] = visible
    end,
    addPanelTab = function()
      return { setBadge = noop }
    end,
    setSelectedPanel = noop,
    setModeClickHandler = function(handler)
      env.modeClick = handler
    end,
    getMode = function()
      return "whispers"
    end,
  }
  env.wiring = PanelWiring.Create({
    factory = factory,
    frame = frame,
    layout = layout,
    chrome = chrome,
    theme = Theme,
    onClose = noop,
    onCoverChanged = function(covered)
      env.covers[#env.covers + 1] = covered
    end,
    getContactsRail = function()
      return rail
    end,
    tabToggle = not noTabToggle and tabToggle or nil,
    onPanelShown = onPanelShown,
    onConversationUncovered = onConversationUncovered,
  })
  return env
end

local function last(list)
  return list[#list]
end

local function fireOnHide(frame)
  for _, h in ipairs(frame._hookScripts.OnHide) do
    h(frame)
  end
end

return function()
  -- test_create_returns_host_and_visibility
  local w = build().wiring
  assert(type(w.panelHost.register) == "function" and type(w.windowVisibility.setPanelVisible) == "function")

  -- test_options_visibility_reaches_tab_toggle_and_rail
  local env = build()
  env.wiring.windowVisibility.setOptionsVisible(true)
  assert(env.optionsShown[#env.optionsShown] == true, "tab toggle saw options shown")
  assert(env.railSeen[#env.railSeen] == true, "rail saw options shown")

  -- test_hook_window_hide_closes_the_panel_only_on_a_real_hide
  env = build()
  w = env.wiring
  w.panelHost.register("ca", { title = "A", onShow = noop })
  w.windowVisibility.setPanelVisible("ca")
  w.hookWindowHide()
  env.frame._hookScripts = env.frame._hookScripts or {}
  fireOnHide(env.frame)
  assert(w.windowVisibility.getVisiblePanel() == "ca", "frame still shown: panel stays")
  env.frame:Hide()
  fireOnHide(env.frame)
  assert(w.windowVisibility.getVisiblePanel() == nil, "real hide closes the panel")

  -- test_on_panel_shown_reports_every_open_but_not_a_close
  local shown = {}
  env = build(false, function(key)
    shown[#shown + 1] = key
  end)
  w = env.wiring
  w.panelHost.register("ca", { title = "A", onShow = noop })
  w.panelHost.register("two", { title = "B", onShow = noop })
  w.windowVisibility.setPanelVisible("ca")
  w.windowVisibility.setPanelVisible("two")
  w.windowVisibility.setPanelVisible(nil)
  assert(table.concat(shown, ",") == "ca,two", "every open reports, close does not, got " .. table.concat(shown, ","))

  -- test_no_tab_toggle_still_registers_and_opens
  w = build(true).wiring
  assert(w.panelHost.register("ca", { title = "A", onShow = noop }) == true, "registers without a strip")
  w.panelHost.refreshBadge("ca")
  assert(w.windowVisibility.setPanelVisible("ca") == true and w.windowVisibility.getVisiblePanel() == "ca", "opens without a strip")
  w.windowVisibility.setPanelVisible(nil)

  -- test_closing_a_panel_reports_the_chat_uncovered
  local uncovered = 0
  env = build(false, nil, function()
    uncovered = uncovered + 1
  end)
  w = env.wiring
  w.panelHost.register("ca", { title = "A", onShow = noop })
  w.windowVisibility.setPanelVisible("ca")
  w.windowVisibility.setPanelVisible(nil)
  assert(uncovered == 1, "panel close reaches onConversationUncovered, got " .. uncovered)

  -- test_mode_tab_click_on_the_current_mode_reports_the_chat_uncovered
  uncovered = 0
  w.windowVisibility.setPanelVisible("ca")
  env.modeClick("whispers")
  assert(uncovered == 1, "same-mode click leaves the panel onto this chat, got " .. uncovered)

  -- test_mode_tab_click_to_another_mode_stays_quiet
  uncovered = 0
  w.windowVisibility.setPanelVisible("ca")
  env.modeClick("groups")
  assert(w.windowVisibility.getVisiblePanel() == nil, "the panel closed")
  assert(uncovered == 0, "the other tab selects its own chat, got " .. uncovered)

  -- test_non_compact_panel_reports_the_window_covered (row 1)
  do
    local e = build()
    e.wiring.panelHost.register("plain", { title = "P", onShow = noop })
    e.wiring.windowVisibility.setPanelVisible("plain")
    assert(last(e.covers) == true, "a panel without the flag covers: " .. tostring(last(e.covers)))
  end

  -- test_compact_panel_reports_the_window_not_covered (row 2)
  do
    local e = build()
    e.wiring.panelHost.register("slim", { title = "S", onShow = noop, compact = true })
    e.wiring.windowVisibility.setPanelVisible("slim")
    assert(#e.covers >= 1 and last(e.covers) == false, "a compact panel does not cover")
    for _, covered in ipairs(e.covers) do
      assert(covered == false, "no cover=true was ever reported")
    end
  end

  -- test_switching_from_a_non_compact_to_a_compact_panel_ends_uncovered (row 3)
  do
    local e = build()
    e.wiring.panelHost.register("plain", { title = "P", onShow = noop })
    e.wiring.panelHost.register("slim", { title = "S", onShow = noop, compact = true })
    e.wiring.windowVisibility.setPanelVisible("plain")
    e.wiring.windowVisibility.setPanelVisible("slim")
    assert(last(e.covers) == false, "ends uncovered: " .. tostring(last(e.covers)))
  end

  -- test_switching_from_a_compact_to_a_non_compact_panel_ends_covered (row 4)
  do
    local e = build()
    e.wiring.panelHost.register("plain", { title = "P", onShow = noop })
    e.wiring.panelHost.register("slim", { title = "S", onShow = noop, compact = true })
    e.wiring.windowVisibility.setPanelVisible("slim")
    e.wiring.windowVisibility.setPanelVisible("plain")
    assert(last(e.covers) == true, "ends covered: " .. tostring(last(e.covers)))
  end

  -- test_settings_over_a_compact_panel_report_covered (row 5)
  do
    local e = build()
    e.wiring.panelHost.register("slim", { title = "S", onShow = noop, compact = true })
    e.wiring.windowVisibility.setPanelVisible("slim")
    e.wiring.windowVisibility.setOptionsVisible(true)
    assert(last(e.covers) == true, "settings cover: " .. tostring(last(e.covers)))
  end

  -- test_a_compact_panel_over_settings_reports_uncovered (row 6)
  do
    local e = build()
    e.wiring.panelHost.register("slim", { title = "S", onShow = noop, compact = true })
    e.wiring.windowVisibility.setOptionsVisible(true)
    e.wiring.windowVisibility.setPanelVisible("slim")
    assert(last(e.covers) == false, "settings hid, the compact panel does not cover: " .. tostring(last(e.covers)))
  end

  -- test_closing_a_compact_panel_reports_uncovered (row 7)
  do
    local e = build()
    e.wiring.panelHost.register("slim", { title = "S", onShow = noop, compact = true })
    e.wiring.windowVisibility.setPanelVisible("slim")
    e.wiring.windowVisibility.setPanelVisible(nil)
    assert(last(e.covers) == false, "closing reports uncovered")
  end
end
