local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TabParts = require("tests.helpers.tab_toggle_parts")
local PanelTemplatesStub = require("tests.helpers.panel_templates_stub")
local Localization = require("WhisperMessenger.Locale.Localization")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")
local NativeTabToggle = require("WhisperMessenger.UI.ContactsList.NativeTabToggle")

local function noop() end

-- Fresh Whispers/Groups strip on a window; `changed` records onModeChanged.
local function build(native)
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  local changed = {}
  local toggle = TabToggle.Create(factory, window, {
    initialMode = "whispers",
    nativeChrome = native,
    windowFrame = window,
    onModeChanged = function(mode)
      changed[#changed + 1] = mode
    end,
  })
  toggle.setModes({ "whispers", "groups" })
  return toggle, changed
end

local function buttons(toggle)
  return FindUI.ofType(toggle.frame, "Button")
end

local function click(btn)
  btn.scripts.OnClick(btn)
end

local function panelLabel(btn, native)
  if native then
    return btn.text
  end
  return FindUI.ofType(btn, "FontString")[1]:GetText()
end

local function contains(list, item)
  for _, value in ipairs(list) do
    if value == item then
      return true
    end
  end
  return false
end

return function()
  for _, native in ipairs({ false, true }) do
    local label = native and "HUD" or "modern"

    -- test_panel_tab_hangs_after_the_mode_tabs
    do
      local toggle = build(native)
      toggle.addPanelTab("ca", "Alerts", noop)
      local b = buttons(toggle)
      local p = b[5].points[1]
      assert(p[1] == "TOPLEFT" and p[2] == b[2] and p[3] == "TOPRIGHT", label .. ": chained after Groups")
    end

    -- test_set_modes_keeps_panel_selected_and_last
    do
      local toggle = build(native)
      toggle.addPanelTab("ca", "Alerts", noop)
      toggle.setSelectedPanel("ca")
      toggle.setModes({ "whispers", "groups", "channels" })
      local b = buttons(toggle)
      assert(toggle.getSelectedPanel() == "ca" and b[5].points[1][2] == b[4], label .. ": still selected, after Channels")
    end

    -- test_panel_tab_label_is_the_title_verbatim
    do
      local toggle = build(native)
      Localization.Configure({ language = "deDE" })
      toggle.addPanelTab("ca", "Groups", noop)
      toggle.setLanguage()
      local b = buttons(toggle)
      local panelText, groupsText = panelLabel(b[5], native), panelLabel(b[2], native)
      Localization.Configure({ language = "enUS" })
      assert(panelText == "Groups" and groupsText == "Gruppen", label .. ": addon title not translated, got " .. tostring(panelText))
    end

    -- test_panel_tab_click_runs_on_click_only
    do
      local toggle, changed = build(native)
      local clicks = {}
      toggle.addPanelTab("ca", "Alerts", function()
        clicks[#clicks + 1] = "ca"
      end)
      click(buttons(toggle)[5])
      assert(clicks[1] == "ca" and #changed == 0 and toggle.getMode() == "whispers", label .. ": panel click runs its onClick only")
    end

    -- test_mode_click_with_panel_selected_calls_handler_first
    do
      local toggle, changed = build(native)
      toggle.addPanelTab("ca", "Alerts", noop)
      local log = {}
      toggle.setModeClickHandler(function(m)
        log[#log + 1] = "handler:" .. m .. ":" .. #changed
        toggle.setSelectedPanel(nil)
      end)
      toggle.setSelectedPanel("ca")
      click(buttons(toggle)[2])
      assert(log[1] == "handler:groups:0" and changed[1] == "groups" and toggle.getSelectedPanel() == nil, label .. ": handler before mode change")
      toggle.setSelectedPanel("ca")
      click(buttons(toggle)[2])
      assert(log[2] == "handler:groups:1" and #changed == 1, label .. ": same mode: handler runs, no second mode event")
    end

    -- test_mode_click_without_panel_skips_handler
    do
      local toggle, changed = build(native)
      toggle.addPanelTab("ca", "Alerts", noop)
      local log = {}
      toggle.setModeClickHandler(function(m)
        log[#log + 1] = m
      end)
      click(buttons(toggle)[2])
      assert(#log == 0 and changed[1] == "groups", label .. ": no panel selected, plain mode switch")
    end

    -- test_set_mode_keeps_panel_selected
    do
      local toggle = build(native)
      toggle.addPanelTab("ca", "Alerts", noop)
      toggle.setSelectedPanel("ca")
      toggle.setMode("groups")
      assert(toggle.getSelectedPanel() == "ca", label .. ": programmatic setMode keeps the panel selected")
    end

    -- test_selected_panel_paints_only_the_panel_tab
    do
      local calls = PanelTemplatesStub.stub()
      local toggle = build(native)
      toggle.addPanelTab("ca", "Alerts", noop)
      local b = buttons(toggle)
      calls.selected, calls.deselected = {}, {}
      toggle.setSelectedPanel("ca")
      if native then
        assert(calls.selected[#calls.selected] == b[5], "HUD: panel tab selected")
        assert(contains(calls.deselected, b[1]), "HUD: Whispers tab deselected")
        assert(not contains(calls.selected, b[1]), "HUD: Whispers tab not selected")
      else
        assert(TabParts.panel(toggle, 1).underline.shown == true, "modern: panel tab underlined")
        assert(TabParts.whispers(toggle).underline.shown == false, "modern: Whispers not underlined")
      end
      calls.selected, calls.deselected = {}, {}
      toggle.setSelectedPanel(nil)
      if native then
        assert(calls.selected[#calls.selected] == b[1] and contains(calls.deselected, b[5]), "HUD: Whispers selected again")
      else
        assert(TabParts.panel(toggle, 1).underline.shown == false, "modern: panel tab underline cleared")
        assert(TabParts.whispers(toggle).underline.shown == true, "modern: Whispers underlined again")
      end
      PanelTemplatesStub.clear()
    end
  end

  -- test_native_panel_tabs_are_named
  do
    local toggle = build(true)
    toggle.addPanelTab("ca", "Alerts", noop)
    toggle.addPanelTab("cb", "Bids", noop)
    local b = buttons(toggle)
    assert(b[5]:GetName() == "WhisperMessengerPanelTab1" and b[6]:GetName() == "WhisperMessengerPanelTab2", "HUD: panel tabs named in order")
  end

  -- test_native_panel_tabs_share_the_width_cap
  do
    local toggle = build(true)
    local strip = toggle.frame
    strip:SetWidth(260)
    strip.scripts.OnSizeChanged(strip, 260, NativeTabToggle.HEIGHT)
    toggle.addPanelTab("ca", "Alerts", noop)
    assert(strip.maxTabWidth == 83, "HUD: panel tab shares the cap, got " .. tostring(strip.maxTabWidth))
  end
end
