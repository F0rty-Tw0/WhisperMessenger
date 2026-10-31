local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Reads EllesmereUI's live look (accent, panel color, font) for the
-- EllesmereUI theme preset. Every call into EllesmereUI is protected: a
-- missing, disabled or changed EllesmereUI only means no live values.
-- EllesmereUI's skinning API: EllesmereUI/SKINNING_API.md.
local Bridge = {}

Bridge.SKIN_NAME = "WhisperMessenger"

local skin = nil
local installed = false
local listeners = {}

local function ellesmere()
  local eui = _G.EllesmereUI
  if type(eui) == "table" then
    return eui
  end
  return nil
end

local function isColor(r, g, b)
  return type(r) == "number" and type(g) == "number" and type(b) == "number"
end

-- Calls a getter returning r, g, b[, a]; nil unless it gives numbers.
local function readColor(getter)
  if type(getter) ~= "function" then
    return nil
  end
  local ok, r, g, b, a = pcall(getter)
  if not ok or not isColor(r, g, b) then
    return nil
  end
  return { r, g, b, type(a) == "number" and a or 1 }
end

local function notify()
  for _, listener in ipairs(listeners) do
    pcall(listener)
  end
end

function Bridge.IsAvailable()
  local eui = ellesmere()
  return eui ~= nil and type(eui.RegisterSkin) == "function"
end

-- Accent as { r, g, b, 1 }: the skin facade after login, else EllesmereUI's
-- own accent (resolved from its saved theme once it has loaded).
function Bridge.Accent()
  local eui = ellesmere()
  if not eui then
    return nil
  end
  local accent = skin and readColor(skin.GetAccentColor)
  if accent then
    return accent
  end
  if skin and type(skin.GetAccentColor) == "function" then
    return nil
  end
  accent = readColor(eui.GetAccentColor)
  if accent then
    return accent
  end
  local green = eui.ELLESMERE_GREEN
  if type(green) == "table" and isColor(green.r, green.g, green.b) then
    return { green.r, green.g, green.b, 1 }
  end
  return nil
end

-- Panel fill as { r, g, b, a }; only the skin facade knows it.
function Bridge.Panel()
  if not ellesmere() or not skin then
    return nil
  end
  return readColor(skin.GetPanelColor)
end

function Bridge.FontPath()
  if not ellesmere() or not skin or type(skin.GetFont) ~= "function" then
    return nil
  end
  local ok, path = pcall(skin.GetFont)
  if ok and type(path) == "string" and path ~= "" then
    return path
  end
  return nil
end

-- fn runs when EllesmereUI's look arrives at login or changes live.
function Bridge.OnChange(fn)
  if type(fn) == "function" then
    listeners[#listeners + 1] = fn
  end
end

-- Registers with EllesmereUI's skin registry once. EllesmereUI runs the
-- callback at login, and never when the player turned skinning off for this
-- addon (the preset then uses EllesmereUI's accent alone).
function Bridge.Install()
  if installed or not Bridge.IsAvailable() then
    return false
  end
  installed = true
  pcall(ellesmere().RegisterSkin, Bridge.SKIN_NAME, function(S)
    if type(S) ~= "table" then
      return
    end
    skin = S
    if type(S.OnLooksChanged) == "function" then
      pcall(S.OnLooksChanged, notify)
    end
    notify()
  end)
  return true
end

-- Tests only: forget the facade, listeners and registration.
function Bridge._Reset()
  skin = nil
  installed = false
  listeners = {}
end

ns.ThemeEllesmereBridge = Bridge
return Bridge
