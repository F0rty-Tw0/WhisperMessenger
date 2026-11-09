-- Coverage guard: every config key a settings panel reads at build time must be
-- forwarded by SettingsPanels. test_settings_panels_forwarding.lua checks the
-- values of known keys; this one catches a key nobody listed, which would show
-- its default after /reload. Keys read only inside later callbacks are not seen.

local FakeUI = require("tests.helpers.fake_ui")
local SettingsPanels = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanels")
local GeneralSettings = require("WhisperMessenger.UI.MessengerWindow.GeneralSettings")
local AppearanceSettings = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")
local WhispersSettings = require("WhisperMessenger.UI.MessengerWindow.WhispersSettings")
local ChatsSettings = require("WhisperMessenger.UI.MessengerWindow.ChatsSettings")
local FiltersSettings = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings")
local NotificationSettings = require("WhisperMessenger.UI.MessengerWindow.NotificationSettings")
local IconSettings = require("WhisperMessenger.UI.MessengerWindow.IconSettings")

local PANELS = {
  { option = "generalCreate", panelKey = "generalPanel", module = GeneralSettings },
  { option = "appearanceCreate", panelKey = "appearancePanel", module = AppearanceSettings },
  { option = "behaviorCreate", panelKey = "behaviorPanel", module = BehaviorSettings },
  { option = "whispersCreate", panelKey = "whispersPanel", module = WhispersSettings },
  { option = "chatsCreate", panelKey = "chatsPanel", module = ChatsSettings },
  { option = "filtersCreate", panelKey = "filtersPanel", module = FiltersSettings },
  { option = "notificationCreate", panelKey = "notificationsPanel", module = NotificationSettings },
  { option = "iconCreate", panelKey = "iconsPanel", module = IconSettings },
}

local SENTINEL = {}

local function captureCreate(captured)
  return function(_factory, _parent, config)
    captured.config = config
    return { frame = {}, refreshLayout = function() end, refreshTheme = function() end }
  end
end

return function()
  -- test_every_config_key_a_panel_reads_is_forwarded_by_settings_panels
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- Pass 1: build each real panel and record the keys it reads from its config.
  local present = {}
  local reads = {}
  local function recordingCreate(index, realCreate)
    present[index] = {}
    reads[index] = {}
    return function(createFactory, panel, config, options)
      for key in pairs(config) do
        present[index][key] = true
      end
      local proxy = setmetatable({}, {
        __index = function(_self, key)
          reads[index][key] = true
          return config[key]
        end,
        __newindex = function(_self, key, value)
          config[key] = value
        end,
      })
      return realCreate(createFactory, panel, proxy, options)
    end
  end

  ---@type table<string, any>
  local passOneOptions = { parent = parent, settingsConfig = {}, storeConfig = {} }
  for index, panel in ipairs(PANELS) do
    passOneOptions[panel.option] = recordingCreate(index, panel.module.Create)
  end

  local panels = SettingsPanels.Create(factory, passOneOptions)
  for index = 1, SettingsPanels.PATCH_NOTES_INDEX - 1 do
    panels.getPanel(index)
  end

  -- A proxy that records nothing would pass pass 2 with nothing to check.
  for index = 1, SettingsPanels.PATCH_NOTES_INDEX - 1 do
    local recorded = next(reads[index]) ~= nil
    assert(recorded, "pass 1 recorded no config reads for " .. PANELS[index].panelKey)
  end

  -- Pass 2: every read key that SettingsPanels did not already supply must come
  -- through from settingsConfig.
  for index = 1, SettingsPanels.PATCH_NOTES_INDEX - 1 do
    for key in pairs(reads[index]) do
      if not present[index][key] then
        local captured = {}
        ---@type table<string, any>
        local options = { parent = parent, settingsConfig = { [key] = SENTINEL } }
        for panelIndex, panel in ipairs(PANELS) do
          options[panel.option] = captureCreate(panelIndex == index and captured or {})
        end
        SettingsPanels.Create(factory, options).getPanel(index)
        assert(
          captured.config and captured.config[key] == SENTINEL,
          PANELS[index].panelKey .. " reads config." .. key .. " but SettingsPanels does not forward it"
        )
      end
    end
  end
end
