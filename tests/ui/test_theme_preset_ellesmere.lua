require("tests.helpers.fake_ui.fontobjects").Install()

local Theme = require("WhisperMessenger.UI.Theme")
local Bridge = require("WhisperMessenger.UI.Theme.EllesmereBridge")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

local FONT_PATH = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.ttf"

local function installEllesmere()
  local facade = {}
  function facade.GetAccentColor()
    return 0.8, 0.2, 0.4
  end
  function facade.GetPanelColor()
    return 0.05, 0.06, 0.07, 0.9
  end
  function facade.GetFont()
    return FONT_PATH, ""
  end
  local eui = {}
  function eui.RegisterSkin(_name, applyFn)
    applyFn(facade)
    return true
  end
  _G.EllesmereUI = eui
  Bridge._Reset()
  Bridge.Install()
  return facade
end

local function listed(key)
  for _, presetKey in ipairs(Theme.ListPresets()) do
    if presetKey == key then
      return true
    end
  end
  return false
end

local function close(a, b)
  return math.abs(a - b) < 0.0001
end

return function()
  Fonts.Initialize("default")

  -- test_ellesmere_preset_hidden_without_ellesmereui
  do
    _G.EllesmereUI = nil
    Bridge._Reset()
    assert(listed("ellesmere_ui") == false, "EllesmereUI preset is not offered without EllesmereUI")
    assert(Theme.SetPreset("ellesmere_ui") == false, "EllesmereUI preset can't be applied without EllesmereUI")
  end

  -- test_saved_ellesmere_preset_falls_back_without_ellesmereui
  do
    local key, applied = Theme.ResolvePreset("ellesmere_ui")
    assert(key == Theme.DEFAULT_PRESET and applied == true, "falls back to the default preset, got " .. tostring(key))
  end

  -- test_ellesmere_preset_listed_with_ellesmereui
  do
    installEllesmere()
    assert(listed("ellesmere_ui") == true, "EllesmereUI preset is offered with EllesmereUI")
  end

  -- test_ellesmere_preset_paints_ellesmere_colors
  do
    installEllesmere()
    assert(Theme.SetPreset("ellesmere_ui") == true, "EllesmereUI preset applies")
    local accent = Theme.COLORS.accent
    assert(close(accent[1], 0.8) and close(accent[2], 0.2) and close(accent[3], 0.4) and accent[4] == 1, "accent is EllesmereUI's")
    assert(close(Theme.COLORS.option_toggle_on[1], 0.8), "toggles use the accent")
    local bg = Theme.COLORS.bg_primary
    assert(close(bg[1], 0.05) and close(bg[2], 0.06) and close(bg[3], 0.07) and close(bg[4], 0.9), "window background is the panel color")
    assert(Theme.COLORS.bg_contact_selected[4] < 0.5, "selected contact is a faint accent wash")
  end

  -- test_ellesmere_preset_uses_ellesmere_font_and_clears_it_after
  do
    installEllesmere()
    Theme.SetPreset("ellesmere_ui")
    assert((_G.WM_Normal:GetFont()) == FONT_PATH, "text uses EllesmereUI's font")
    Theme.SetPreset("elvui_dark")
    assert((_G.WM_Normal:GetFont()) ~= FONT_PATH, "other presets keep their font")
  end

  -- test_chosen_font_family_wins_over_the_ellesmere_font
  do
    local FAMILY_PATH = "Interface\\AddOns\\SharedMedia\\Family.ttf"
    local savedLibStub = rawget(_G, "LibStub")
    local lsm = {
      Fetch = function(_, _, name)
        return name == "Family" and FAMILY_PATH or nil
      end,
    }
    rawset(
      _G,
      "LibStub",
      setmetatable({}, {
        __call = function()
          return lsm
        end,
      })
    )
    installEllesmere()
    Fonts.SetMode("Family")
    Theme.SetPreset("ellesmere_ui")
    local path = _G.WM_Normal:GetFont()
    Fonts.SetMode("default")
    rawset(_G, "LibStub", savedLibStub)
    Theme.SetPreset(Theme.DEFAULT_PRESET)
    assert(path == FAMILY_PATH, "the chosen font family wins, got " .. tostring(path))
  end

  -- test_cjk_and_cyrillic_clients_keep_their_locale_font_under_the_ellesmere_preset
  for _, locale in ipairs({ "koKR", "zhCN", "zhTW", "ruRU" }) do
    local savedGetLocale = rawget(_G, "GetLocale")
    rawset(_G, "GetLocale", function()
      return locale
    end)
    installEllesmere()
    Theme.SetPreset("ellesmere_ui")
    local path = _G.WM_Normal:GetFont()
    rawset(_G, "GetLocale", savedGetLocale)
    Theme.SetPreset(Theme.DEFAULT_PRESET)
    assert(path ~= FONT_PATH, locale .. " client keeps the game's font, got " .. tostring(path))
  end

  -- test_only_the_ellesmere_preset_is_live
  do
    assert(Theme.IsLivePreset("ellesmere_ui") == true, "EllesmereUI preset follows live changes")
    assert(Theme.IsLivePreset("elvui_dark") == false, "fixed presets are not live")
  end

  -- test_reapplying_rereads_ellesmere_colors
  do
    local facade = installEllesmere()
    Theme.SetPreset("ellesmere_ui")
    facade.GetAccentColor = function()
      return 0.1, 0.9, 0.1
    end
    assert(Theme.SetPreset("ellesmere_ui") == true, "re-applies")
    assert(close(Theme.COLORS.accent[2], 0.9), "new accent picked up")
  end

  _G.EllesmereUI = nil
  Bridge._Reset()
  Theme.SetPreset(Theme.DEFAULT_PRESET)
end
