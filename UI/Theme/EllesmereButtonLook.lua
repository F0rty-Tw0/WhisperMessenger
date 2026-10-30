local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- How EllesmereUI draws its action buttons, for the widget's square under
-- the EllesmereUI theme: slot background, Action Bar 1's border, and the
-- Bar Animations hover ("highlight") and pushed effects. Read from
-- EllesmereUI Action Bars' profile (keys as in its EllesmereUIActionBars.lua
-- defaults); every call is protected, and without the module (or on any
-- error) the result is EllesmereUI's defaults with plain fills.
local ButtonLook = {}

local MEDIA = "Interface\\AddOns\\EllesmereUIActionBars\\Media\\"
local BORDER_PX = { none = 0, thin = 1, normal = 2, heavy = 3, strong = 4 }
local DEFAULT_EFFECT_COLOR = { r = 0.973, g = 0.839, b = 0.604, a = 1 }
local FILL_ALPHA = 0.35 -- EllesmereUI's "fill" effect type
local DEFAULT_TYPE = 2

local function profile()
  local eui = _G.EllesmereUI
  local lite = type(eui) == "table" and eui.Lite
  if type(lite) ~= "table" or type(lite.GetAddon) ~= "function" then
    return nil
  end
  local ok, addon = pcall(lite.GetAddon, "EllesmereUIActionBars", true)
  local db = ok and type(addon) == "table" and addon.db
  local p = type(db) == "table" and db.profile
  return type(p) == "table" and p or nil
end

local function classColor()
  local unitClass, colors = _G.UnitClass, _G.RAID_CLASS_COLORS
  if type(unitClass) ~= "function" or type(colors) ~= "table" then
    return nil
  end
  local ok, _, classFile = pcall(unitClass, "player")
  local c = ok and classFile and colors[classFile]
  return type(c) == "table" and c or nil
end

local function color(c, alpha)
  return { c.r or 0, c.g or 0, c.b or 0, alpha or c.a or 1 }
end

-- Bar Animations' hover or pushed effect, prefix "highlight" or "pushed":
-- types 1-3 its textures, 4 a fill, 5 a border, 6 none.
local function effect(p, prefix)
  local base = type(p[prefix .. "CustomColor"]) == "table" and p[prefix .. "CustomColor"] or DEFAULT_EFFECT_COLOR
  local tint = color(base)
  local cc = p[prefix .. "UseClassColor"] and classColor()
  if cc then
    tint = { cc.r, cc.g, cc.b, tint[4] }
  end
  local kind = tonumber(p[prefix .. "TextureType"]) or DEFAULT_TYPE
  if kind <= 3 then
    -- A button's highlight is drawn added on, its pushed texture normally.
    return { kind = "tex", path = MEDIA .. "highlight-" .. (kind + 1) .. ".png", color = tint, blend = prefix == "highlight" and "ADD" or "BLEND" }
  elseif kind == 4 then
    return { kind = "fill", color = { tint[1], tint[2], tint[3], FILL_ALPHA } }
  elseif kind == 5 then
    return { kind = "edge", color = tint, px = tonumber(p[prefix .. "BorderSize"]) or 4 }
  end
  return { kind = "none" }
end

local function defaults()
  return {
    bg = { 0.15, 0.15, 0.15, 0.5 },
    border = { 0, 0, 0, 1 },
    borderPx = 1,
    hover = { kind = "fill", color = { 1, 1, 1, 0.15 } },
    push = { kind = "fill", color = { 1, 1, 1, 0.25 } },
  }
end

local function read()
  local look = defaults()
  local p = profile()
  if not p then
    return look
  end
  if type(p.slotBgColor) == "table" then
    look.bg = color(p.slotBgColor, (tonumber(p.slotBgOpacity) or 50) / 100)
  end
  local bar = type(p.bars) == "table" and type(p.bars.MainBar) == "table" and p.bars.MainBar or {}
  if type(bar.borderColor) == "table" then
    look.border = color(bar.borderColor)
  end
  local cc = bar.borderClassColor and classColor()
  if cc then
    look.border = { cc.r, cc.g, cc.b, look.border[4] }
  end
  look.borderPx = tonumber(bar.borderThicknessPx) or BORDER_PX[bar.borderThickness or "thin"] or 1
  look.hover = effect(p, "highlight")
  look.push = effect(p, "pushed")
  return look
end

function ButtonLook.Read()
  local ok, look = pcall(read)
  if ok and type(look) == "table" then
    return look
  end
  return defaults()
end

ns.ThemeEllesmereButtonLook = ButtonLook
return ButtonLook
