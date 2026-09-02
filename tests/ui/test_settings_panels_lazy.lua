local FakeUI = require("tests.helpers.fake_ui")
local SettingsPanels = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanels")
local SettingsTabs = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Buttons.SettingsTabs")

local function makeSettingsView(createCounts, name)
  return function(factory, parent)
    createCounts[name] = createCounts[name] + 1
    local frame = factory.CreateFrame("Frame", nil, parent)
    factory.CreateFrame("Frame", nil, frame)
    return { frame = frame }
  end
end

local function makeTab(factory, parent)
  local tab = factory.CreateFrame("Frame", nil, parent)
  tab.bg = tab:CreateTexture(nil, "BACKGROUND")
  return tab
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local createCounts = {
    general = 0,
    appearance = 0,
    behavior = 0,
    notifications = 0,
    icons = 0,
  }

  local panels = SettingsPanels.Create(factory, {
    parent = parent,
    generalCreate = makeSettingsView(createCounts, "general"),
    appearanceCreate = makeSettingsView(createCounts, "appearance"),
    behaviorCreate = makeSettingsView(createCounts, "behavior"),
    notificationCreate = makeSettingsView(createCounts, "notifications"),
    iconCreate = makeSettingsView(createCounts, "icons"),
  })

  assert(type(panels.getPanel) == "function", "settings panels must expose a lazy panel getter")

  local generalTab = makeTab(factory, parent)
  local appearanceTab = makeTab(factory, parent)
  local behaviorTab = makeTab(factory, parent)
  local notificationsTab = makeTab(factory, parent)
  local iconsTab = makeTab(factory, parent)

  SettingsTabs.Wire({
    settingsTabs = { generalTab, appearanceTab, behaviorTab, notificationsTab, iconsTab },
    settingsPanels = panels.settingsPanels,
  })

  assert(createCounts.general == 1, "default general tab must construct its panel")
  assert(createCounts.appearance == 0, "unopened appearance tab must allocate no frame tree")
  assert(createCounts.behavior == 0, "unopened behavior tab must allocate no frame tree")
  assert(createCounts.notifications == 0, "unopened notifications tab must allocate no frame tree")
  assert(createCounts.icons == 0, "unopened icons tab must allocate no frame tree")

  appearanceTab.scripts.OnClick(appearanceTab)
  assert(createCounts.appearance == 1, "opening appearance tab must construct its frame tree")

  generalTab.scripts.OnClick(generalTab)
  appearanceTab.scripts.OnClick(appearanceTab)
  assert(createCounts.appearance == 1, "reopening appearance tab must reuse its frame tree")
end
