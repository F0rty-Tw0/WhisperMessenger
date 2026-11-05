local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Desaturation = {}

Desaturation.DESAT_GREY = { 0.45, 0.45, 0.45, 0.6 }
-- The back bubble's idle gray on the circle: opaque, so it reads over the dark circle.
Desaturation.DESAT_BACK = { 0.55, 0.55, 0.55, 1 }

-- Tracks the unread count: the look is idle (isActive) while the setting is on
-- and nothing is unread. The caller paints; this paints nothing.
-- deps.getIconDesaturated: () -> boolean, the "gray when idle" setting.
function Desaturation.Create(deps)
  local getIconDesaturated = deps.getIconDesaturated

  local lastUnreadCount = 0

  local function isActive()
    return getIconDesaturated and getIconDesaturated() and lastUnreadCount == 0
  end

  local function update(unreadCount)
    lastUnreadCount = tonumber(unreadCount) or 0
  end

  local function refresh()
    update(lastUnreadCount)
  end

  return {
    update = update,
    refresh = refresh,
    isActive = isActive,
  }
end

ns.ToggleIconDesaturation = Desaturation
return Desaturation
