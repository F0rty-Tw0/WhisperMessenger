local FakeUI = require("tests.helpers.fake_ui")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local WindowVisibility = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowVisibility")
local Buttons = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Buttons")

local function count(log, entry)
  local n = 0
  for _, e in ipairs(log) do
    if e == entry then
      n = n + 1
    end
  end
  return n
end

local function indexOf(log, entry)
  for i, e in ipairs(log) do
    if e == entry then
      return i
    end
  end
  return nil
end

-- opts.showResult: what the stub host's show returns (default true);
-- opts.noHost: build without a panelHost; opts.onShow(key, env): runs inside
-- the stub host's show, like a panel's onShow does. env.shown holds the keys
-- whose frames the stub host has shown and not hidden.
local function build(opts)
  opts = opts or {}
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", "Window", nil)
  local env = {
    log = {},
    shown = {},
    frame = frame,
    optionsPanel = factory.CreateFrame("Frame", nil, frame),
    contactsPane = factory.CreateFrame("Frame", nil, frame),
    contentPane = factory.CreateFrame("Frame", nil, frame),
  }
  frame.contactsInset = factory.CreateFrame("Frame", nil, frame)
  frame.conversationInset = factory.CreateFrame("Frame", nil, frame)
  env.contactsPane:Show()
  env.contentPane:Show()
  frame.contactsInset:Show()
  frame.conversationInset:Show()
  local log = env.log
  local panelHost = nil
  if not opts.noHost then
    panelHost = {
      show = function(key)
        log[#log + 1] = "show:" .. key
        env.shown[key] = true
        if opts.onShow then
          opts.onShow(key, env)
        end
        return opts.showResult ~= false
      end,
      hide = function(key)
        log[#log + 1] = "hide:" .. key
        env.shown[key] = nil
      end,
    }
  end
  env.v = WindowVisibility.Create({
    optionsPanel = env.optionsPanel,
    contactsPane = env.contactsPane,
    contentPane = env.contentPane,
    frame = frame,
    panelHost = panelHost,
    onClose = function()
      log[#log + 1] = "close"
    end,
    onOptionsVisibilityChanged = function(visible)
      log[#log + 1] = "options:" .. tostring(visible)
    end,
    onPanelVisibilityChanged = function(open)
      log[#log + 1] = "panel:" .. tostring(open)
    end,
  })
  return env
end

local function panesShown(env)
  return env.contactsPane:IsShown() and env.contentPane:IsShown() and env.frame.contactsInset:IsShown() and env.frame.conversationInset:IsShown()
end

local function panesHidden(env)
  return not env.contactsPane:IsShown()
    and not env.contentPane:IsShown()
    and not env.frame.contactsInset:IsShown()
    and not env.frame.conversationInset:IsShown()
end

local function joined(log)
  return table.concat(log, ",")
end

local function partA()
  -- test_show_panel_hides_panes_and_insets
  do
    local env = build()
    assert(env.v.setPanelVisible("ca") == true and env.v.getVisiblePanel() == "ca")
    assert(panesHidden(env), "panes and insets hidden while the panel shows")
    assert(joined(env.log) == "show:ca,panel:true", "log: " .. joined(env.log))
  end

  -- test_close_panel_restores_panes_and_insets
  do
    local env = build()
    env.v.setPanelVisible("ca")
    local opened = #env.log
    assert(env.v.setPanelVisible(nil) == true)
    assert(table.concat(env.log, ",", opened + 1) == "hide:ca,panel:false", "log: " .. joined(env.log))
    assert(panesShown(env), "panes and insets back")
    assert(env.v.getVisiblePanel() == nil)
  end

  -- test_opening_options_closes_the_panel_once (Review Focus 4)
  do
    local env = build()
    env.v.setPanelVisible("ca")
    env.v.setOptionsVisible(true)
    assert(count(env.log, "hide:ca") == 1, "panel closed once: " .. joined(env.log))
    assert(env.optionsPanel:IsShown(), "options shown")
    assert(env.v.getVisiblePanel() == nil)
    assert(indexOf(env.log, "panel:false") < indexOf(env.log, "options:true"), "panel closes before options open")
  end

  -- test_opening_a_panel_closes_options
  do
    local env = build()
    env.v.setOptionsVisible(true)
    assert(env.v.setPanelVisible("ca") == true)
    assert(not env.optionsPanel:IsShown(), "options hidden")
    local optionsOff, shown = indexOf(env.log, "options:false"), indexOf(env.log, "show:ca")
    assert(optionsOff ~= nil and shown ~= nil and optionsOff < shown, "options close before the panel shows: " .. joined(env.log))
    assert(panesHidden(env), "panes stay hidden under the panel")
  end

  -- test_switching_panels_hides_the_old_first
  do
    local env = build()
    env.v.setPanelVisible("a")
    assert(env.v.setPanelVisible("b") == true)
    local hideA, showB = indexOf(env.log, "hide:a"), indexOf(env.log, "show:b")
    assert(hideA ~= nil and showB ~= nil and hideA < showB, "old panel hides first: " .. joined(env.log))
    assert(env.v.getVisiblePanel() == "b" and panesHidden(env))
  end

  -- test_set_options_false_closes_an_open_panel (Back path)
  do
    local env = build()
    env.v.setPanelVisible("ca")
    env.v.setOptionsVisible(false)
    assert(count(env.log, "hide:ca") == 1, "Back closes the panel once")
    assert(env.v.getVisiblePanel() == nil and panesShown(env))
  end

  -- test_close_window_closes_panel_then_window
  do
    local env = build()
    env.v.setPanelVisible("ca")
    env.v.closeWindow()
    assert(count(env.log, "hide:ca") == 1, "closing the window closes the panel once")
    assert(indexOf(env.log, "hide:ca") < indexOf(env.log, "close"), "panel closes before the window")
  end

  -- test_a_panel_showing_another_panel_from_its_show_leaves_one_tracked
  do
    local env = build({
      onShow = function(key, e)
        if key == "a" then
          e.v.setPanelVisible("b")
        end
      end,
    })
    assert(env.v.setPanelVisible("a") == true)
    assert(env.v.getVisiblePanel() == "b", "the panel it moved to is the open one, got " .. tostring(env.v.getVisiblePanel()))
    assert(env.shown.b == true and env.shown.a == nil, "exactly one panel frame shown")
    assert(panesHidden(env), "panes stay hidden")
    assert(env.v.setPanelVisible(nil) == true)
    assert(next(env.shown) == nil, "closing leaves no panel frame shown")
    assert(panesShown(env), "panes back")
  end

  -- test_host_refusal_changes_nothing
  do
    local env = build({ showResult = false })
    assert(env.v.setPanelVisible("ca") == false)
    assert(panesShown(env), "panes untouched")
    assert(count(env.log, "panel:true") == 0 and env.v.getVisiblePanel() == nil)
  end

  -- test_no_panel_host_is_inert
  do
    local env = build({ noHost = true })
    assert(env.v.setPanelVisible("x") == false)
    assert(env.v.getVisiblePanel() == nil and panesShown(env))
  end

  -- test_close_without_open_panel_is_a_no_op
  do
    local env = build()
    env.v.setOptionsVisible(true)
    local before = #env.log
    assert(env.v.setPanelVisible(nil) == false)
    assert(#env.log == before, "no host call or callback: " .. joined(env.log))
    assert(env.optionsPanel:IsShown(), "options stay open")
    assert(not env.contactsPane:IsShown() and not env.contentPane:IsShown(), "panes stay hidden")
  end

  -- test_toggle_panel_opens_then_closes
  do
    local env = build()
    env.v.togglePanel("ca")
    assert(env.v.getVisiblePanel() == "ca")
    env.v.togglePanel("ca")
    assert(env.v.getVisiblePanel() == nil and panesShown(env))
  end

  -- test_toggle_other_panel_switches
  do
    local env = build()
    env.v.togglePanel("a")
    env.v.togglePanel("b")
    assert(env.v.getVisiblePanel() == "b")
  end
end

local function partB()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { useNativeChrome = false })
  local frame = chrome.frame
  local optionsPanel = factory.CreateFrame("Frame", nil, frame)
  local contactsPane = factory.CreateFrame("Frame", nil, frame)
  local contentPane = factory.CreateFrame("Frame", nil, frame)
  contactsPane:Show()
  contentPane:Show()
  local visibility = WindowVisibility.Create({
    optionsPanel = optionsPanel,
    contactsPane = contactsPane,
    contentPane = contentPane,
    frame = frame,
    panelHost = {
      show = function()
        return true
      end,
      hide = function() end,
    },
    onOptionsVisibilityChanged = chrome.setOptionsActive,
    onPanelVisibilityChanged = chrome.setBackVisible,
  })
  Buttons.WireButtons({
    optionsButton = chrome.optionsButton,
    backButton = chrome.backButton,
    optionsPanel = optionsPanel,
  }, {
    setOptionsVisible = visibility.setOptionsVisible,
    isShown = function(f)
      return f:IsShown()
    end,
  })

  -- test_panel_shows_back
  visibility.setPanelVisible("ca")
  assert(chrome.backButton:IsShown(), "Back shows while a panel is open")

  -- test_back_closes_the_panel
  chrome.backButton:GetScript("OnClick")(chrome.backButton)
  assert(visibility.getVisiblePanel() == nil, "Back closes the panel")
  assert(not chrome.backButton:IsShown(), "Back hides after closing the panel")
  assert(contactsPane:IsShown() and contentPane:IsShown(), "Back restores the panes")

  -- test_gear_closes_the_panel
  visibility.setPanelVisible("ca")
  chrome.optionsButton:GetScript("OnClick")(chrome.optionsButton)
  assert(optionsPanel:IsShown(), "gear opens options")
  assert(visibility.getVisiblePanel() == nil, "gear closes the panel")
  assert(chrome.backButton:IsShown(), "Back stays for the options pane")
end

return function()
  partA()
  partB()
end
