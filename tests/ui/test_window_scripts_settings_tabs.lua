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

  SettingsTabs.Wire({
    optionsPanel = factory.CreateFrame("Frame", nil, parent),
    optionsScrollView = nil,
    settingsTabs = { generalTab, appearanceTab, behaviorTab, notificationsTab },
    settingsPanels = { generalPanel, appearancePanel, behaviorPanel, notificationsPanel },
    theme = Theme,
  })

  assert(generalPanel.shown == true, "generalPanel should be shown by default")
  assert(appearancePanel.shown == false, "appearancePanel should be hidden by default")
  assert(behaviorPanel.shown == false, "behaviorPanel should be hidden by default")
  assert(notificationsPanel.shown == false, "notificationsPanel should be hidden by default")

  appearanceTab.scripts.OnClick(appearanceTab)
  assert(generalPanel.shown == false, "generalPanel should hide after appearance click")
  assert(appearancePanel.shown == true, "appearancePanel should show after appearance click")

  notificationsTab.mouseOver = true
  notificationsTab.scripts.OnClick(notificationsTab)
  assert(notificationsPanel.shown == true, "notificationsPanel should show after notifications click")

  if notificationsTab.scripts.OnLeave then
    notificationsTab.mouseOver = false
    notificationsTab.scripts.OnLeave(notificationsTab)
  end

  local activeColor = Theme.COLORS.option_button_active
    or Theme.COLORS.bg_contact_selected
    or { 0.16, 0.18, 0.28, 0.80 }
  assert(
    notificationsTab.bg.color[1] == activeColor[1] and notificationsTab.bg.color[2] == activeColor[2],
    "active tab background should persist after leave"
  )
end
