local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local RetailHud = require("tests.helpers.retail_hud")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")

-- Like the live client, SetScript drops the hooks HookScript added before it.
local function withLiveSetScript(factory)
  local create = factory.CreateFrame
  factory.CreateFrame = function(...)
    local frame = create(...)
    local setScript = frame.SetScript
    frame.SetScript = function(self, eventName, handler)
      if self._hookScripts then
        self._hookScripts[eventName] = nil
      end
      return setScript(self, eventName, handler)
    end
    return frame
  end
  return factory
end

local function build()
  local factory = withLiveSetScript(FakeUI.NewFactory())
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1280, 720)
  local window = MessengerWindow.Create(factory, {})
  _G.UIParent = savedUIParent
  window.frame:Show()
  return window
end

-- Registers a panel and returns its tab (the strip's fifth button, after the
-- four mode tabs) plus a record of what the panel's callbacks saw.
local function register(window)
  local seen = { hides = 0 }
  local ok = window.registerPanel("ca", {
    title = "Alerts",
    onShow = function(host)
      seen.host = host
    end,
    onHide = function()
      seen.hides = seen.hides + 1
    end,
  })
  assert(ok == true, "registerPanel accepts a valid panel")
  local button = FindUI.ofType(window.tabToggle.frame, "Button")[5]
  assert(button ~= nil, "the strip got a panel tab")
  return button, seen
end

local function click(button)
  button:GetScript("OnClick")(button)
end

local function runStyle(label, expectHostParent)
  -- test_registered_panel_tab_opens_the_panel
  do
    local window = build()
    local button, seen = register(window)
    click(button)
    assert(window.getVisiblePanel() == "ca", label .. ": tab opens the panel")
    assert(not window.contactsPane:IsShown() and not window.contentPane:IsShown(), label .. ": panes hidden")
    assert(window.backButton:IsShown(), label .. ": Back shown")
    assert(not window.optionsPanel:IsShown(), label .. ": options hidden")
    assert(seen.host ~= nil and seen.host:GetParent() == expectHostParent(window), label .. ": host parent")
  end

  -- test_back_returns_to_the_list
  do
    local window = build()
    local button, seen = register(window)
    click(button)
    click(window.backButton)
    assert(window.getVisiblePanel() == nil, label .. ": Back closes the panel")
    assert(seen.hides == 1, label .. ": onHide once, got " .. seen.hides)
    assert(window.contactsPane:IsShown() and window.contentPane:IsShown(), label .. ": panes back")
    assert(not window.backButton:IsShown(), label .. ": Back hidden")
  end

  -- test_clicking_the_open_panel_tab_again_is_ignored
  do
    local window = build()
    local button, seen = register(window)
    click(button)
    click(button)
    assert(window.getVisiblePanel() == "ca" and seen.hides == 0, label .. ": second click keeps the panel open")
    assert(not window.contactsPane:IsShown(), label .. ": panes stay hidden after the second click")
  end

  -- test_hiding_the_window_closes_the_panel_once
  do
    local window = build()
    local button, seen = register(window)
    click(button)
    window.frame:Hide()
    assert(seen.hides == 1, label .. ": window hide closes the panel once, got " .. seen.hides)
    assert(window.getVisiblePanel() == nil, label .. ": no panel after the window hides")
  end

  -- test_a_parent_hide_keeps_the_panel_open (Alt+Z, cinematics: the window
  -- frame itself is still shown, only its parent is hidden)
  do
    local window = build()
    local button, seen = register(window)
    click(button)
    assert(window.frame:IsShown(), "the frame itself stays shown")
    for _, hook in ipairs(window.frame._hookScripts.OnHide) do
      hook(window.frame)
    end
    assert(window.getVisiblePanel() == "ca" and seen.hides == 0, label .. ": the panel stays open, onHide not called")
  end

  -- test_hiding_the_window_keeps_options_open
  do
    local window = build()
    click(window.optionsButton)
    window.frame:Hide()
    assert(window.optionsPanel:IsShown(), label .. ": options survive a window hide")
  end

  -- test_gear_closes_the_panel (Review Focus 4)
  do
    local window = build()
    local button, seen = register(window)
    click(button)
    click(window.optionsButton)
    assert(window.optionsPanel:IsShown(), label .. ": gear opens options")
    assert(seen.hides == 1 and window.getVisiblePanel() == nil, label .. ": gear closes the panel once")
    click(button)
    assert(not window.optionsPanel:IsShown() and window.getVisiblePanel() == "ca", label .. ": panel tab closes options")
  end

  -- test_refresh_panel_badge_reaches_the_host
  do
    local window = build()
    register(window)
    window.refreshPanelBadge("ca")
    window.refreshPanelBadge("unknown")
  end

  -- test_show_and_hide_panel_from_the_window
  do
    local window = build()
    local _, seen = register(window)
    assert(window.showPanel("ca") == true and window.getVisiblePanel() == "ca", label .. ": showPanel opens")
    window.hidePanel()
    assert(window.getVisiblePanel() == nil and seen.hides == 1, label .. ": hidePanel closes")
    assert(window.showPanel("unknown") == false, label .. ": unknown key")
  end
end

return function()
  runStyle("modern", function(window)
    return window.frame
  end)

  RetailHud.With(function()
    runStyle("retail", function(window)
      return window.frame.contentArea
    end)

    -- test_retail_insets_hidden_while_the_panel_shows
    local window = build()
    local frame = window.frame
    frame.contactsInset:Show()
    frame.conversationInset:Show()
    local button = register(window)
    click(button)
    assert(not frame.contactsInset:IsShown() and not frame.conversationInset:IsShown(), "retail: insets hidden under the panel")
    click(window.backButton)
    assert(frame.contactsInset:IsShown() and frame.conversationInset:IsShown(), "retail: insets back after Back")
  end)
end
