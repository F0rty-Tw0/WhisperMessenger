-- Settings changes that interact with the Native WoW HUD.
local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local Presets = require("WhisperMessenger.UI.Theme.Presets")
local RetailHud = require("tests.helpers.retail_hud")

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

-- Records StaticPopup_Show / StaticPopup_Hide names and ReloadUI calls.
local function withPopups(fn)
  local saved = {
    dialogs = rawget(_G, "StaticPopupDialogs"),
    show = rawget(_G, "StaticPopup_Show"),
    hide = rawget(_G, "StaticPopup_Hide"),
    reload = rawget(_G, "ReloadUI"),
  }
  local popups = { shown = {}, hidden = {}, reloads = 0 }
  rawset(_G, "StaticPopupDialogs", {})
  rawset(_G, "StaticPopup_Show", function(name)
    popups.shown[#popups.shown + 1] = name
  end)
  rawset(_G, "StaticPopup_Hide", function(name)
    popups.hidden[#popups.hidden + 1] = name
  end)
  rawset(_G, "ReloadUI", function()
    popups.reloads = popups.reloads + 1
  end)
  local ok, err = pcall(fn, popups)
  rawset(_G, "StaticPopupDialogs", saved.dialogs)
  rawset(_G, "StaticPopup_Show", saved.show)
  rawset(_G, "StaticPopup_Hide", saved.hide)
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
  -- test_hud_style_saves_and_mirrors_native_chrome_on_reload
  for _, case in ipairs({ { "classic", true }, { "retail", true }, { "off", false } }) do
    local style, expectedNative = case[1], case[2]
    withPopups(function(popups)
      local accountSettings = { nativeChrome = not expectedNative }
      local onChange = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = accountSettings })
      onChange("hudStyle", style)
      if popups.shown[1] then
        _G.StaticPopupDialogs[popups.shown[1]].OnAccept()
      end
      assert(accountSettings.hudStyle == style, style .. ": hudStyle saved")
      assert(accountSettings.nativeChrome == expectedNative, style .. ": nativeChrome mirrors the style for older versions")
    end)
  end

  -- test_hud_style_waits_for_the_reload_before_saving
  withPopups(function()
    local accountSettings = { hudStyle = "off", nativeChrome = false }
    local onChange = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = accountSettings })
    onChange("hudStyle", "classic")
    assert(accountSettings.hudStyle == "off", "not saved before Reload UI, got " .. tostring(accountSettings.hudStyle))
    assert(accountSettings.nativeChrome == false, "nativeChrome not saved before Reload UI")
  end)

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

  -- test_picking_again_while_the_popup_is_up_keeps_the_new_pick
  -- Blizzard's StaticPopup_Show cancels a visible dialog of the same name
  -- with reason "override" before showing it again, unless the dialog sets
  -- noCancelOnReuse.
  withPopups(function(popups)
    local visible = false
    rawset(_G, "StaticPopup_Show", function(name)
      local dialog = _G.StaticPopupDialogs[name]
      if visible and not dialog.noCancelOnReuse then
        dialog.OnCancel({}, nil, "override")
      end
      visible = true
      popups.shown[#popups.shown + 1] = name
    end)
    local accountSettings = { hudStyle = "off" }
    local onChange = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = accountSettings })
    onChange("hudStyle", "classic")
    onChange("hudStyle", "classic")
    _G.StaticPopupDialogs[popups.shown[2]].OnAccept()
    assert(accountSettings.hudStyle == "classic", "second pick saved on Reload UI, got " .. tostring(accountSettings.hudStyle))
  end)

  -- test_override_cancel_keeps_the_pending_pick
  withPopups(function(popups)
    local accountSettings = { hudStyle = "off" }
    local onChange = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = accountSettings })
    onChange("hudStyle", "classic")
    local dialog = _G.StaticPopupDialogs[popups.shown[1]]
    dialog.OnCancel({}, nil, "override")
    dialog.OnAccept()
    assert(accountSettings.hudStyle == "classic", "a re-show cancel is not the player's Cancel, got " .. tostring(accountSettings.hudStyle))
  end)

  -- test_cancelling_the_popup_discards_the_choice
  withChatFrame(function(messages)
    withPopups(function(popups)
      local accountSettings = { hudStyle = "off" }
      local shown = {}
      local runtime = makeRuntime()
      runtime.window = {
        appearanceSettings = {
          setHudStyle = function(style)
            shown[#shown + 1] = style
          end,
        },
      }
      local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings })
      onChange("hudStyle", "classic")
      _G.StaticPopupDialogs[popups.shown[1]].OnCancel()
      assert(popups.reloads == 0, "Cancel does not reload")
      assert(accountSettings.hudStyle == "off", "Cancel keeps the saved style, got " .. tostring(accountSettings.hudStyle))
      assert(shown[1] == "off", "the picker shows the saved style again, got " .. tostring(shown[1]))
      assert(#messages == 0, "no /reload reminder: nothing is pending")
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
    local accountSettings = { hudStyle = "off" }
    local onChange2 = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = accountSettings })
    onChange("hudStyle", "classic")
    onChange2("hudStyle", "classic")
    Hud.Configure("off")
    assert(#popups.shown == 0, "same style as this session: no popup")
    assert(accountSettings.hudStyle == "classic", "the running style saves at once")
  end)

  -- test_picking_the_running_style_again_closes_the_pending_popup
  withPopups(function(popups)
    local onChange = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = {} })
    onChange("hudStyle", "classic")
    onChange("hudStyle", "off")
    assert(#popups.hidden == 1 and popups.hidden[1] == popups.shown[1], "back to the running style hides the reload popup")
  end)

  -- test_a_stale_popup_does_not_switch_to_azeroth
  withPopups(function(popups)
    local accountSettings = { themePreset = "elvui_dark" }
    local onChange = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = accountSettings })
    onChange("hudStyle", "classic")
    onChange("hudStyle", "off")
    _G.StaticPopupDialogs[popups.shown[1]].OnAccept()
    assert(accountSettings.themePreset == "elvui_dark", "HUD back off: preset kept, got " .. tostring(accountSettings.themePreset))
  end)

  -- test_moving_between_hud_styles_keeps_the_preset
  RetailHud.With(function()
    Hud.Configure("classic")
    withPopups(function(popups)
      local accountSettings = { themePreset = "elvui_dark" }
      local onChange = SettingsHandler.Create({ runtime = makeRuntime(), accountSettings = accountSettings })
      onChange("hudStyle", "retail")
      assert(#popups.shown == 1, "Classic to Modern offers a reload")
      _G.StaticPopupDialogs[popups.shown[1]].OnAccept()
      assert(accountSettings.themePreset == "elvui_dark", "Classic to Modern keeps the preset, got " .. tostring(accountSettings.themePreset))
    end)
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
