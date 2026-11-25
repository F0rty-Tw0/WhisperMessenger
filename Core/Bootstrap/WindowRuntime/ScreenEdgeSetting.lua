local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The live reaction to the screen edge settings. ctx: runtime,
-- ensureSurface() (returns the surface), updateIconSurfaces(), readCompactSlot().
local ScreenEdgeSetting = {}

local KEYS = { screenEdge = true, edgeGlow = true, edgeGlowColor = true, edgeGlowCustom = true }
-- A colour change only repaints: the picker sends one on every drag step.
local COLOUR_KEYS = { edgeGlowColor = true, edgeGlowCustom = true }

function ScreenEdgeSetting.Apply(ctx, key, _value)
  if not KEYS[key] then
    return
  end
  local window = ctx.runtime.window
  -- A window that was never at the edge stays put (Reset to Defaults re-sends "off").
  if key == "screenEdge" and window and window.applyScreenEdge then
    window.applyScreenEdge(ctx.readCompactSlot())
  end
  local surface = ctx.ensureSurface()
  if COLOUR_KEYS[key] then
    if surface then
      surface.refresh()
    end
    return
  end
  ctx.updateIconSurfaces()
end

ns.BootstrapWindowRuntimeScreenEdgeSetting = ScreenEdgeSetting
return ScreenEdgeSetting
