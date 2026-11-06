local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local withPopups = require("tests.helpers.reload_popups").With

local function build(running, settings)
  local case = { settings = settings or {}, shownOnToggle = {}, docks = 0, sizes = {} }
  case.runtime = {
    store = { config = {} },
    phoneLayoutActive = running,
    window = {
      appearanceSettings = {
        setPhoneLayout = function(enabled)
          table.insert(case.shownOnToggle, enabled)
        end,
      },
      dockPhoneIcon = function()
        table.insert(case.sizes, "dock")
      end,
    },
  }
  case.onChange = SettingsHandler.Create({
    runtime = case.runtime,
    accountSettings = case.settings,
    getIcon = function()
      return {
        applyIconSize = function(size)
          table.insert(case.sizes, size)
        end,
      }
    end,
  })
  return case
end

return function()
  -- test_changing_the_window_style_offers_a_reload
  withPopups(function(popups)
    local case = build(true)
    case.onChange("phoneLayout", false)
    assert(#popups.shown == 1, "the player is offered a reload")
    _G.StaticPopupDialogs[popups.shown[1]].OnCancel()
  end)

  -- test_cancelling_the_reload_puts_the_toggle_back
  withPopups(function(popups)
    local case = build(true, { phoneLayout = true })
    case.onChange("phoneLayout", false)
    _G.StaticPopupDialogs[popups.shown[1]].OnCancel()
    assert(case.settings.phoneLayout == true, "nothing saved")
    assert(case.shownOnToggle[1] == true, "the toggle shows the saved style again")
  end)

  -- test_a_changed_icon_mode_updates_the_window_after_applying
  do
    local order = {}
    local runtime = {
      store = { config = {} },
      window = {
        dockPhoneIcon = function()
          table.insert(order, "dock")
        end,
      },
    }
    local onChange = SettingsHandler.Create({
      runtime = runtime,
      accountSettings = {},
      applyIconMode = function()
        table.insert(order, "mode")
      end,
    })
    onChange("iconMode", "minimap")
    assert(order[1] == "mode" and order[2] == "dock", "the window sees the new mode")
  end

  -- test_a_changed_icon_size_docks_after_resizing
  do
    local case = build(true)
    case.onChange("iconSize", 50)
    assert(case.sizes[1] == 50 and case.sizes[2] == "dock", "the spot is worked out from the new size")
  end
end
