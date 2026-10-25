local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")

-- One row per cell of the panel-tab state x event table: a modern window
-- with panels "ca" and "two" registered in that order. `modeEvents` logs
-- every onTabModeChanged; `seen[key].hides` counts each panel's onHide.
local function build(settingsConfig, skipPanels, onPanelShown)
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1280, 720)
  local modeEvents = {}
  local window = MessengerWindow.Create(factory, {
    settingsConfig = settingsConfig,
    onPanelShown = onPanelShown,
    onTabModeChanged = function(mode)
      modeEvents[#modeEvents + 1] = mode
    end,
  })
  _G.UIParent = savedUIParent
  window.frame:Show()
  local seen = {}
  if not skipPanels then
    for _, key in ipairs({ "ca", "two" }) do
      seen[key] = { hides = 0 }
      local ok = window.registerPanel(key, {
        title = key,
        onShow = function() end,
        onHide = function()
          seen[key].hides = seen[key].hides + 1
        end,
      })
      assert(ok == true, "registerPanel " .. key)
    end
  end
  return window, modeEvents, seen
end

local PANEL_INDEX = { ca = 5, two = 6 }

local function buttons(window)
  return FindUI.ofType(window.tabToggle.frame, "Button")
end

local function tab(window, key)
  local button = buttons(window)[PANEL_INDEX[key]]
  assert(button ~= nil, "panel tab " .. key)
  return button
end

local function modeTab(window, i)
  return buttons(window)[i]
end

local function click(b)
  b:GetScript("OnClick")(b)
end

return function()
  -- test_click_panel_tab_opens_and_selects_it
  do
    local window = build()
    click(tab(window, "ca"))
    assert(window.getVisiblePanel() == "ca", "panel open")
    assert(window.tabToggle.getSelectedPanel() == "ca", "panel tab selected")
    assert(window.tabToggle.frame:IsShown(), "strip stays up over the panel")
  end

  -- test_only_whispers_plus_one_panel_shows_the_strip
  do
    local window = build({ showGroupChats = false }, true)
    assert(not window.tabToggle.frame:IsShown(), "whispers alone: no strip")
    window.registerPanel("ca", { title = "ca", onShow = function() end })
    assert(window.tabToggle.frame:IsShown(), "whispers + one panel: strip shown")
  end

  -- test_mode_tab_other_mode_closes_panel_and_switches
  do
    local window, modeEvents = build()
    click(tab(window, "ca"))
    click(modeTab(window, 2))
    assert(window.getVisiblePanel() == nil, "panel closed")
    assert(window.contactsPane:IsShown(), "contacts back")
    assert(window.getTabMode() == "groups", "switched to groups")
    assert(#modeEvents == 1 and modeEvents[1] == "groups", "one mode event, got " .. #modeEvents)
    assert(window.tabToggle.getSelectedPanel() == nil, "selection cleared")
  end

  -- test_mode_tab_same_mode_closes_panel_without_mode_event
  do
    local window, modeEvents = build()
    click(tab(window, "ca"))
    click(modeTab(window, 1))
    assert(window.getVisiblePanel() == nil, "panel closed")
    assert(#modeEvents == 0, "no mode event, got " .. #modeEvents)
    assert(window.tabToggle.getSelectedPanel() == nil, "selection cleared")
  end

  -- test_other_panel_tab_swaps_panels
  do
    local window, _, seen = build()
    click(tab(window, "ca"))
    click(tab(window, "two"))
    assert(seen.ca.hides == 1, "first panel hidden once, got " .. seen.ca.hides)
    assert(window.getVisiblePanel() == "two", "second panel open")
    assert(window.tabToggle.getSelectedPanel() == "two", "second tab selected")
  end

  -- test_gear_closes_panel_and_hides_strip
  do
    local window = build()
    click(tab(window, "ca"))
    click(window.optionsButton)
    assert(not window.tabToggle.frame:IsShown(), "strip hidden under options")
    assert(window.getVisiblePanel() == nil, "panel closed by the gear")
    click(window.backButton)
    assert(window.tabToggle.frame:IsShown(), "strip back after options close")
    assert(window.tabToggle.getSelectedPanel() == nil, "mode tab selected again")
  end

  -- test_back_and_hide_panel_clear_selection
  do
    local window = build()
    click(tab(window, "ca"))
    click(window.backButton)
    assert(window.tabToggle.getSelectedPanel() == nil, "Back clears the selection")
    click(tab(window, "ca"))
    window.hidePanel()
    assert(window.tabToggle.getSelectedPanel() == nil, "hidePanel clears the selection")
  end

  -- test_window_hide_clears_selected_panel
  do
    local window = build()
    click(tab(window, "ca"))
    window.frame:Hide()
    window.frame:Show()
    assert(window.tabToggle.getSelectedPanel() == nil, "reopen: no panel selected")
    assert(window.getVisiblePanel() == nil, "reopen: no panel open")
    assert(window.getTabMode() == "whispers", "reopen: mode tab kept")
  end

  -- test_programmatic_set_tab_mode_keeps_panel_open
  do
    local window = build()
    click(tab(window, "ca"))
    window.setTabMode("groups")
    assert(window.getVisiblePanel() == "ca", "panel stays open")
    assert(window.tabToggle.getSelectedPanel() == "ca", "panel stays selected")
  end

  -- test_show_panel_over_options_shows_strip_and_selects
  do
    local window = build()
    click(window.optionsButton)
    assert(not window.tabToggle.frame:IsShown(), "strip hidden under options")
    window.showPanel("ca")
    assert(window.tabToggle.frame:IsShown(), "strip back with the panel")
    assert(window.tabToggle.getSelectedPanel() == "ca", "panel tab selected")
  end

  -- test_every_panel_open_path_reports_to_on_panel_shown: tab click, API
  -- showPanel and a swap from another panel; closing reports nothing.
  do
    local shown = {}
    local window = build(nil, false, function(key)
      shown[#shown + 1] = key
    end)
    click(tab(window, "ca"))
    window.showPanel("two")
    click(tab(window, "ca"))
    window.showPanel(nil)
    assert(table.concat(shown, ",") == "ca,two,ca", "got " .. table.concat(shown, ","))
  end
end
