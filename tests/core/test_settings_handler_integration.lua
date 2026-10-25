-- Allow addon integration is read once at load, so a change is saved only
-- when the player reloads from the popup.
local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local withPopups = require("tests.helpers.reload_popups").With

local KEY = "allowAddonIntegration"

-- shown: what the Behavior page was told to show after a Cancel.
local function makeHandler(accountSettings)
  local shown = {}
  local runtime = {
    store = { config = {} },
    window = {
      behaviorSettings = {
        setAllowAddonIntegration = function(on)
          shown[#shown + 1] = on
        end,
      },
    },
  }
  return SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings }), shown
end

return function()
  -- test_turning_integration_off_asks_to_reload_and_saves_nothing
  withPopups(function(popups)
    local accountSettings = {}
    local onChange = makeHandler(accountSettings)
    onChange(KEY, false)
    assert(#popups.shown == 1, "one reload popup, got " .. #popups.shown)
    local dialog = _G.StaticPopupDialogs[popups.shown[1]]
    assert(type(dialog.text) == "string" and dialog.text ~= "", "the popup explains the reload")
    assert(accountSettings[KEY] == nil, "nothing saved before Reload UI, got " .. tostring(accountSettings[KEY]))
  end)

  -- test_accepting_the_popup_saves_then_reloads
  withPopups(function(popups)
    local accountSettings = {}
    local onChange = makeHandler(accountSettings)
    onChange(KEY, false)
    local savedAtReload
    rawset(_G, "ReloadUI", function()
      savedAtReload = accountSettings[KEY]
    end)
    _G.StaticPopupDialogs[popups.shown[1]].OnAccept()
    assert(savedAtReload == false, "saved before the reload, got " .. tostring(savedAtReload))
  end)

  -- test_cancelling_the_popup_keeps_the_saved_value_and_resets_the_toggle
  withPopups(function(popups)
    local accountSettings = { [KEY] = false }
    local onChange, shown = makeHandler(accountSettings)
    onChange(KEY, true)
    _G.StaticPopupDialogs[popups.shown[1]].OnCancel()
    assert(popups.reloads == 0, "Cancel does not reload")
    assert(accountSettings[KEY] == false, "Cancel keeps the saved value, got " .. tostring(accountSettings[KEY]))
    assert(#shown == 1 and shown[1] == false, "the toggle shows the saved value again, got " .. tostring(shown[1]))
  end)

  -- test_going_back_to_the_running_value_saves_and_hides_the_popup
  withPopups(function(popups)
    local accountSettings = {}
    local onChange = makeHandler(accountSettings)
    onChange(KEY, false)
    onChange(KEY, true)
    assert(accountSettings[KEY] == true, "the running value saves at once, got " .. tostring(accountSettings[KEY]))
    assert(#popups.hidden == 1 and popups.hidden[1] == popups.shown[1], "the pending popup is hidden")
    _G.StaticPopupDialogs[popups.shown[1]].OnAccept()
    assert(accountSettings[KEY] == true, "a stale popup saves nothing, got " .. tostring(accountSettings[KEY]))
  end)

  -- test_the_running_value_with_nothing_pending_leaves_other_popups_alone
  withPopups(function(popups)
    local accountSettings = { [KEY] = false }
    local onChange = makeHandler(accountSettings)
    onChange(KEY, false)
    assert(#popups.shown == 0 and #popups.hidden == 0, "no popup shown or hidden")
    assert(accountSettings[KEY] == false, "kept off")
  end)

  -- test_the_running_hud_style_leaves_the_integration_popup_up
  -- Appearance -> Reset to Defaults sends the running HUD style while the
  -- integration prompt waits; it must not close that prompt.
  withPopups(function(popups)
    local accountSettings = {}
    local onChange = makeHandler(accountSettings)
    onChange(KEY, false)
    onChange("hudStyle", "off")
    assert(#popups.hidden == 0, "the integration popup stays up, hid " .. #popups.hidden)
    _G.StaticPopupDialogs[popups.shown[1]].OnAccept()
    assert(accountSettings[KEY] == false, "its Reload UI still saves, got " .. tostring(accountSettings[KEY]))
  end)
end
