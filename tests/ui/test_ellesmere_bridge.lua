local Bridge = require("WhisperMessenger.UI.Theme.EllesmereBridge")

-- A stand-in for EllesmereUI: RegisterSkin hands back the facade the way the
-- real one does at login.
local function fakeEllesmere(facade)
  local eui = { registered = {} }
  function eui.RegisterSkin(name, applyFn)
    eui.registered[#eui.registered + 1] = name
    eui.apply = function()
      applyFn(facade)
    end
    return true
  end
  return eui
end

local function fakeFacade()
  local S = { looksCallbacks = {} }
  function S.GetAccentColor()
    return 0.8, 0.2, 0.4
  end
  function S.GetPanelColor()
    return 0.05, 0.06, 0.07, 0.9
  end
  function S.GetFont()
    return "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.ttf", ""
  end
  function S.OnLooksChanged(fn)
    S.looksCallbacks[#S.looksCallbacks + 1] = fn
  end
  return S
end

local function close(a, b)
  return math.abs(a - b) < 0.0001
end

return function()
  -- test_unavailable_without_ellesmereui
  do
    Bridge._Reset()
    _G.EllesmereUI = nil
    assert(Bridge.IsAvailable() == false, "no EllesmereUI means not available")
    assert(Bridge.Accent() == nil, "no EllesmereUI means no accent")
    assert(Bridge.Panel() == nil, "no EllesmereUI means no panel color")
    assert(Bridge.FontPath() == nil, "no EllesmereUI means no font")
    assert(Bridge.Install() == false, "install does nothing without EllesmereUI")
  end

  -- test_accent_falls_back_to_the_global_accent_before_login
  do
    Bridge._Reset()
    local eui = fakeEllesmere(fakeFacade())
    eui.ELLESMERE_GREEN = { r = 0.1, g = 0.2, b = 0.3 }
    _G.EllesmereUI = eui
    assert(Bridge.IsAvailable() == true, "EllesmereUI with RegisterSkin is available")
    local accent = assert(Bridge.Accent(), "accent from ELLESMERE_GREEN")
    assert(close(accent[1], 0.1) and close(accent[2], 0.2) and close(accent[3], 0.3), "accent copies ELLESMERE_GREEN")
    eui.GetAccentColor = function()
      return 0.4, 0.5, 0.6
    end
    accent = assert(Bridge.Accent(), "accent from GetAccentColor")
    assert(close(accent[1], 0.4) and close(accent[3], 0.6), "GetAccentColor wins over ELLESMERE_GREEN")
  end

  -- test_skin_facade_supplies_accent_panel_and_font
  do
    Bridge._Reset()
    local facade = fakeFacade()
    local eui = fakeEllesmere(facade)
    _G.EllesmereUI = eui
    assert(Bridge.Install() == true, "install registers the skin")
    assert(Bridge.Install() == false, "install runs once")
    assert(#eui.registered == 1 and eui.registered[1] == "WhisperMessenger", "registered under the addon's folder name")
    eui.apply()
    local accent = assert(Bridge.Accent(), "accent from the facade")
    assert(close(accent[1], 0.8) and close(accent[2], 0.2) and close(accent[3], 0.4), "facade accent")
    local panel = assert(Bridge.Panel(), "panel from the facade")
    assert(close(panel[1], 0.05) and close(panel[4], 0.9), "facade panel color")
    assert(Bridge.FontPath() == "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.ttf", "facade font")
  end

  -- test_listeners_hear_login_and_live_look_changes
  do
    Bridge._Reset()
    local facade = fakeFacade()
    local eui = fakeEllesmere(facade)
    _G.EllesmereUI = eui
    local calls = 0
    Bridge.OnChange(function()
      calls = calls + 1
    end)
    Bridge.Install()
    eui.apply()
    assert(calls == 1, "skin callback notifies, got " .. calls)
    assert(#facade.looksCallbacks == 1, "subscribes to look changes")
    facade.looksCallbacks[1]()
    assert(calls == 2, "look change notifies, got " .. calls)
  end

  -- test_errors_inside_ellesmereui_are_contained
  do
    Bridge._Reset()
    local facade = fakeFacade()
    facade.GetAccentColor = function()
      error("broken accent")
    end
    facade.GetPanelColor = function()
      return "not", "a", "color"
    end
    facade.GetFont = function()
      error("broken font")
    end
    local eui = fakeEllesmere(facade)
    eui.RegisterSkin = function(_name, applyFn)
      applyFn(facade)
      error("broken register")
    end
    _G.EllesmereUI = eui
    Bridge.Install()
    assert(Bridge.Accent() == nil, "a failing accent getter gives no accent")
    assert(Bridge.Panel() == nil, "a non-number panel color is ignored")
    assert(Bridge.FontPath() == nil, "a failing font getter gives no font")
  end

  -- test_a_failing_listener_does_not_stop_the_others
  do
    Bridge._Reset()
    local facade = fakeFacade()
    local eui = fakeEllesmere(facade)
    _G.EllesmereUI = eui
    local heard = false
    Bridge.OnChange(function()
      error("listener failed")
    end)
    Bridge.OnChange(function()
      heard = true
    end)
    Bridge.Install()
    eui.apply()
    assert(heard == true, "second listener still runs")
  end

  Bridge._Reset()
  _G.EllesmereUI = nil
end
