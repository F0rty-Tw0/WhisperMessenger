local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local SettingsTabs = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Buttons.SettingsTabs")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  local generalPanel = factory.CreateFrame("Frame", nil, parent)
  local appearancePanel = factory.CreateFrame("Frame", nil, parent)
  local behaviorPanel = factory.CreateFrame("Frame", nil, parent)
  local notificationsPanel = factory.CreateFrame("Frame", nil, parent)
  local iconsPanel = factory.CreateFrame("Frame", nil, parent)
  generalPanel._testContentHeight = 100
  appearancePanel._testContentHeight = 200
  behaviorPanel._testContentHeight = 300
  notificationsPanel._testContentHeight = 400
  iconsPanel._testContentHeight = 500

  local scrollContent = {
    SetHeight = function(self, height)
      self.height = height
    end,
  }
  local optionsScrollView = { content = scrollContent }
  local scrollPosition = nil
  local scrollSyncs = 0
  local scrollView = {
    SetVerticalScroll = function(_, value)
      scrollPosition = value
    end,
    Sync = function()
      scrollSyncs = scrollSyncs + 1
    end,
  }

  local function makeTab()
    local tab = factory.CreateFrame("Frame", nil, parent)
    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(tab)
    bg:SetColorTexture(0.14, 0.15, 0.20, 0.80)
    tab.bg = bg
    return tab
  end

  local generalTab = makeTab()
  local appearanceTab = makeTab()
  local behaviorTab = makeTab()
  local notificationsTab = makeTab()
  local iconsTab = makeTab()

  SettingsTabs.Wire({
    optionsPanel = factory.CreateFrame("Frame", nil, parent),
    optionsScrollView = optionsScrollView,
    settingsTabs = { generalTab, appearanceTab, behaviorTab, notificationsTab, iconsTab },
    settingsPanels = { generalPanel, appearancePanel, behaviorPanel, notificationsPanel, iconsPanel },
    theme = Theme,
    scrollView = scrollView,
    measurePanelContentHeight = function(panel)
      return panel._testContentHeight
    end,
  })

  assert(generalPanel.shown == true, "generalPanel should be shown by default")
  assert(appearancePanel.shown == false, "appearancePanel should be hidden by default")
  assert(behaviorPanel.shown == false, "behaviorPanel should be hidden by default")
  assert(notificationsPanel.shown == false, "notificationsPanel should be hidden by default")
  assert(iconsPanel.shown == false, "iconsPanel should be hidden by default")

  appearanceTab.scripts.OnClick(appearanceTab)
  assert(generalPanel.shown == false, "generalPanel should hide after appearance click")
  assert(appearancePanel.shown == true, "appearancePanel should show after appearance click")

  notificationsTab.mouseOver = true
  notificationsTab.scripts.OnClick(notificationsTab)
  assert(notificationsPanel.shown == true, "notificationsPanel should show after notifications click")
  iconsTab.scripts.OnClick(iconsTab)
  assert(iconsPanel.shown == true, "iconsPanel should show after fifth-tab click")
  assert(notificationsPanel.shown == false, "notificationsPanel should hide after fifth-tab click")
  assert(scrollContent.height == 500, "fifth tab should resize scroll content to its panel")
  assert(scrollPosition == 0, "fifth tab should reset shared scroll position")
  assert(scrollSyncs > 0, "fifth tab should sync the shared scroll view")

  if notificationsTab.scripts.OnLeave then
    notificationsTab.mouseOver = false
    notificationsTab.scripts.OnLeave(notificationsTab)
  end

  local activeColor = Theme.COLORS.option_button_active or Theme.COLORS.bg_contact_selected or { 0.16, 0.18, 0.28, 0.80 }
  assert(
    iconsTab.bg.color[1] == activeColor[1] and iconsTab.bg.color[2] == activeColor[2],
    "active fifth-tab background should persist after leave"
  )
end
