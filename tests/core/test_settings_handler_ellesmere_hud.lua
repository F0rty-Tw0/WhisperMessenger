-- Picking the EllesmereUI preset under a Native WoW HUD offers to turn the
-- HUD off, since the HUD's Blizzard frame art hides most of the theme.
local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local Bridge = require("WhisperMessenger.UI.Theme.EllesmereBridge")
local withPopups = require("tests.helpers.reload_popups").With

local QUESTION = "The EllesmereUI theme shows best with the Native WoW HUD off. Turn it off and reload the interface now?"

local function makeRuntime(shown)
  local runtime = { store = { config = {} } }
  runtime.window = {
    appearanceSettings = {
      setHudStyle = function(style)
        shown[#shown + 1] = style
      end,
    },
  }
  return runtime
end

-- Runs fn with EllesmereUI loaded and the given HUD style running.
local function withEllesmere(style, fn)
  rawset(_G, "EllesmereUI", {
    RegisterSkin = function()
      return true
    end,
  })
  Bridge._Reset()
  Hud.Configure(style)
  local ok, err = pcall(fn)
  Theme.SetPreset(Theme.DEFAULT_PRESET)
  Hud.Configure("off")
  rawset(_G, "EllesmereUI", nil)
  Bridge._Reset()
  if not ok then
    error(err, 0)
  end
end

local function create(accountSettings, shown)
  return SettingsHandler.Create({ runtime = makeRuntime(shown), accountSettings = accountSettings, theme = Theme })
end

return function()
  -- test_ellesmere_preset_under_hud_offers_to_turn_the_hud_off
  withEllesmere("classic", function()
    withPopups(function(popups)
      local shown = {}
      local accountSettings = { hudStyle = "classic", themePreset = "wow_native" }
      create(accountSettings, shown)("themePreset", "ellesmere_ui")
      assert(accountSettings.themePreset == "ellesmere_ui", "preset applies at once")
      assert(#popups.shown == 1, "one popup, got " .. #popups.shown)
      assert(_G.StaticPopupDialogs[popups.shown[1]].text == QUESTION, "the popup says why")
      assert(shown[1] == "off", "the HUD picker shows Off while the popup asks")
      assert(accountSettings.hudStyle == "classic", "HUD not saved before the reload")
    end)
  end)

  -- test_accepting_turns_the_hud_off_and_keeps_the_preset
  withEllesmere("retail", function()
    withPopups(function(popups)
      local accountSettings = { hudStyle = "retail", themePreset = "wow_native" }
      create(accountSettings, {})("themePreset", "ellesmere_ui")
      _G.StaticPopupDialogs[popups.shown[1]].OnAccept()
      assert(accountSettings.hudStyle == "off", "HUD off on reload, got " .. tostring(accountSettings.hudStyle))
      assert(accountSettings.themePreset == "ellesmere_ui", "preset kept, got " .. tostring(accountSettings.themePreset))
      assert(popups.reloads == 1, "reloads the interface")
    end)
  end)

  -- test_cancelling_keeps_the_hud_and_the_preset
  withEllesmere("classic", function()
    withPopups(function(popups)
      local shown = {}
      local accountSettings = { hudStyle = "classic", themePreset = "wow_native" }
      create(accountSettings, shown)("themePreset", "ellesmere_ui")
      _G.StaticPopupDialogs[popups.shown[1]].OnCancel()
      assert(accountSettings.hudStyle == "classic", "Cancel keeps the HUD, got " .. tostring(accountSettings.hudStyle))
      assert(accountSettings.themePreset == "ellesmere_ui", "Cancel keeps the preset")
      assert(shown[#shown] == "classic", "the HUD picker shows the saved style again")
      assert(popups.reloads == 0, "Cancel does not reload")
    end)
  end)

  -- test_no_offer_with_the_hud_off
  withEllesmere("off", function()
    withPopups(function(popups)
      create({ hudStyle = "off" }, {})("themePreset", "ellesmere_ui")
      assert(#popups.shown == 0, "nothing to turn off")
    end)
  end)

  -- test_no_offer_for_other_presets
  withEllesmere("classic", function()
    withPopups(function(popups)
      create({ hudStyle = "classic", themePreset = "wow_native" }, {})("themePreset", "elvui_dark")
      assert(#popups.shown == 0, "only the EllesmereUI preset asks")
    end)
  end)

  -- test_no_offer_when_the_preset_is_applied_again
  -- EllesmereUI look changes re-apply the preset; that must not ask again.
  withEllesmere("classic", function()
    withPopups(function(popups)
      create({ hudStyle = "classic", themePreset = "ellesmere_ui" }, {})("themePreset", "ellesmere_ui")
      assert(#popups.shown == 0, "already chosen: no popup")
    end)
  end)
end
