local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScreenEdgeGlow = ns.ToggleIconScreenEdgeGlow or require("WhisperMessenger.UI.ToggleIcon.ScreenEdgeGlow")

-- The icon surface at the screen edge. IconSurfaces hands it the unread
-- counts; it lights the glow while the window is hidden.
local ScreenEdgeSurface = {}

-- options: theme, settings, getSide(), isWindowShown().
function ScreenEdgeSurface.Create(factory, parent, options)
  local settings = options.settings
  local glow = ScreenEdgeGlow.Create(factory, parent, { theme = options.theme, settings = settings })
  local surface = { glow = glow }
  surface.total, surface.whispers = 0, 0

  function surface.refresh()
    local side = options.getSide()
    local closed = side ~= nil and not options.isWindowShown()
    glow.setSide(side)
    glow.paint()
    glow.setLit(closed and settings.edgeGlow ~= false and surface.whispers > 0)
  end

  function surface.setUnreadCount(nextTotal, nextWhispers)
    surface.total, surface.whispers = nextTotal or 0, nextWhispers or 0
    surface.refresh()
  end

  surface.refreshTheme = glow.refreshTheme

  surface.refresh()
  return surface
end

ns.ToggleIconScreenEdgeSurface = ScreenEdgeSurface

return ScreenEdgeSurface
