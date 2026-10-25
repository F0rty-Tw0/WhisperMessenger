local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local PanelRegistry = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelRegistry")

local function recorder()
  local last = {}
  return last, {
    setUnreadCount = function(count, pulseCount)
      last.count = count
      last.pulseCount = pulseCount
    end,
  }
end

return function()
  -- test_badge_settings_resync_keeps_the_panel_badges
  do
    local registry = PanelRegistry.New()
    registry.register("ca", {
      badge = function()
        return 2
      end,
    })
    local widget, icon = recorder()
    local map, minimap = recorder()
    local onChange = SettingsHandler.Create({
      runtime = { store = { config = {} }, panelRegistry = registry },
      accountSettings = {},
      getIcon = function()
        return icon
      end,
      getMinimapIcon = function()
        return minimap
      end,
      buildContacts = function()
        return { { unreadCount = 1 } }
      end,
    })
    for _, key in ipairs({ "showUnreadBadge", "badgePulse" }) do
      onChange(key, true)
      assert(widget.count == 3 and widget.pulseCount == 1, key .. ": widget count 3, pulse count 1; got " .. tostring(widget.count))
      assert(map.count == 3 and map.pulseCount == 1, key .. ": minimap count 3, pulse count 1; got " .. tostring(map.count))
    end
  end
end
