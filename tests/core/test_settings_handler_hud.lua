-- Settings changes that interact with the Native WoW HUD.
local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local Presets = require("WhisperMessenger.UI.Theme.Presets")

local function makeRuntime()
  return { store = { config = {} } }
end

local function sameColor(a, b)
  return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

local function withChatFrame(fn)
  local saved = rawget(_G, "DEFAULT_CHAT_FRAME")
  local messages = {}
  rawset(_G, "DEFAULT_CHAT_FRAME", {
    AddMessage = function(_self, text)
      messages[#messages + 1] = text
    end,
  })
  local ok, err = pcall(fn, messages)
  rawset(_G, "DEFAULT_CHAT_FRAME", saved)
  if not ok then
    error(err, 0)
  end
end

-- Records StaticPopup_Show names and ReloadUI calls.
local function withPopups(fn)
  local saved = {
    dialogs = rawget(_G, "StaticPopupDialogs"),
    show = rawget(_G, "StaticPopup_Show"),
    reload = rawget(_G, "ReloadUI"),
  }
  local popups = { shown = {}, reloads = 0 }
  rawset(_G, "StaticPopupDialogs", {})
  rawset(_G, "StaticPopup_Show", function(name)
    popups.shown[#popups.shown + 1] = name
  end)
  rawset(_G, "ReloadUI", function()
    popups.reloads = popups.reloads + 1
  end)
  local ok, err = pcall(fn, popups)
  rawset(_G, "StaticPopupDialogs", saved.dialogs)
  rawset(_G, "StaticPopup_Show", saved.show)
  rawset(_G, "ReloadUI", saved.reload)
  if not ok then
    error(err, 0)
  end
end

local function underHud(fn)
  Hud.Configure("classic")
  local ok, err = pcall(fn)
  Theme.SetPreset(Theme.DEFAULT_PRESET)
  Hud.Configure("off")
  if not ok then
    error(err, 0)
  end
end

return function()
  -- test_hud_style_persists_and_mirrors_native_chrome
  for _, case in ipairs({ { "classic", true }, { "retail", true }, { "off", false } }) do
    local style, expectedNative = case[1], case[2]
    local accountSettings = { nativeChrome = not expectedNative }
    local onChange = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = accountSettings })
    onChange("hudStyle", style)
    assert(accountSettings.hudStyle == style, style .. ": hudStyle persisted")
    assert(accountSettings.nativeChrome == expectedNative, style .. ": nativeChrome mirrors the style for older versions")
  end

  -- test_hud_style_change_offers_a_reload_popup
  withChatFrame(function(messages)
    withPopups(function(popups)
      local onChange = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = {} })
      onChange("hudStyle", "classic")
      assert(#popups.shown == 1, "one reload popup, got " .. #popups.shown)
      local dialog = _G.StaticPopupDialogs[popups.shown[1]]
      assert(dialog and type(dialog.text) == "string" and dialog.text ~= "", "the popup explains the reload")
      assert(#messages == 0, "no chat notice while the popup asks")
    end)
  end)

  -- test_accepting_the_popup_reloads_the_interface
  withPopups(function(popups)
    local onChange = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = {} })
    onChange("hudStyle", "classic")
    _G.StaticPopupDialogs[popups.shown[1]].OnAccept()
    assert(popups.reloads == 1, "Reload UI reloads the interface, got " .. popups.reloads)
  end)

  -- test_cancelling_the_popup_keeps_the_choice_and_reminds_in_chat
  withChatFrame(function(messages)
    withPopups(function(popups)
      local accountSettings = {}
      local onChange = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = accountSettings })
      onChange("hudStyle", "classic")
      _G.StaticPopupDialogs[popups.shown[1]].OnCancel()
      assert(popups.reloads == 0, "Cancel does not reload")
      assert(accountSettings.hudStyle == "classic", "Cancel keeps the saved choice")
      assert(#messages == 1 and string.find(messages[1], "/reload", 1, true), "Cancel prints the /reload reminder")
    end)
  end)

  -- test_accepting_the_reload_switches_a_hud_style_to_azeroth
  for _, style in ipairs({ "classic", "retail" }) do
    withPopups(function(popups)
      local accountSettings = { themePreset = "elvui_dark" }
      local onChange = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = accountSettings })
      onChange("hudStyle", style)
      assert(accountSettings.themePreset == "elvui_dark", style .. ": preset waits for the reload")
      local presetAtReload
      rawset(_G, "ReloadUI", function()
        presetAtReload = accountSettings.themePreset
      end)
      _G.StaticPopupDialogs[popups.shown[1]].OnAccept()
      assert(presetAtReload == Presets.WOW_NATIVE, style .. ": Azeroth is saved before the reload, got " .. tostring(presetAtReload))
    end)
  end

  -- test_cancelling_the_reload_keeps_the_preset
  withChatFrame(function()
    withPopups(function(popups)
      local accountSettings = { themePreset = "elvui_dark" }
      local onChange = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = accountSettings })
      onChange("hudStyle", "classic")
      _G.StaticPopupDialogs[popups.shown[1]].OnCancel()
      assert(accountSettings.themePreset == "elvui_dark", "Cancel keeps the preset, got " .. tostring(accountSettings.themePreset))
    end)
  end)

  -- test_turning_the_hud_off_keeps_the_preset_on_reload
  withPopups(function(popups)
    Hud.Configure("classic")
    local accountSettings = { themePreset = "elvui_dark" }
    local onChange = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = accountSettings })
    onChange("hudStyle", "off")
    Hud.Configure("off")
    _G.StaticPopupDialogs[popups.shown[1]].OnAccept()
    assert(accountSettings.themePreset == "elvui_dark", "Off keeps the preset, got " .. tostring(accountSettings.themePreset))
  end)

  -- test_picking_the_running_style_needs_no_reload
  withPopups(function(popups)
    Hud.Configure("classic")
    local onChange = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = {} })
    onChange("hudStyle", "classic")
    Hud.Configure("off")
    assert(#popups.shown == 0, "same style as this session: no popup")
  end)

  -- test_theme_preset_still_applies_under_hud
  underHud(function()
    local accountSettings = {}
    local onChange = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = accountSettings, theme = Theme })
    onChange("themePreset", "elvui_dark")
    assert(accountSettings.themePreset == "elvui_dark", "preset saved, got " .. tostring(accountSettings.themePreset))
    assert(sameColor(Theme.COLORS.bg_primary, assert(Presets.Get("elvui_dark")).bg_primary), "the chosen preset paints under the HUD")
  end)

  -- test_font_colour_still_applies_under_hud
  underHud(function()
    local applied = {}
    local onChange = SettingsHandler.Create({
      runtime = makeRuntime(),
      accountSettings = {},
      fonts = {
        SetFontColor = function(key)
          applied[#applied + 1] = key
        end,
      },
    })
    onChange("fontColor", "gold")
    assert(applied[1] == "gold", "font colour applies under the HUD")
  end)
end
