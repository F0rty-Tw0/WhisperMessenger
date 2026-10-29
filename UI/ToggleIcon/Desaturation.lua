local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Desaturation = {}

local DESAT_GREY = { 0.45, 0.45, 0.45, 0.6 }
local DESAT_BG = { 0.25, 0.25, 0.25, 0.7 }

-- deps.textures and deps.resolveColors share keys (e.g. chatIcon,
-- background, border, accentGlyph); `background` grays to DESAT_BG, every
-- other texture to DESAT_GREY.
function Desaturation.Create(deps)
  local textures = deps.textures
  local resolveColors = deps.resolveColors
  local getIconDesaturated = deps.getIconDesaturated
  local applyVertexColor = deps.applyVertexColor

  local lastUnreadCount = 0
  -- Snapshot original colors. Re-read on every theme refresh so preset
  -- switches propagate through the desaturate path.
  local originalColors = {}
  local function refreshOriginalColors()
    for key in pairs(textures) do
      originalColors[key] = resolveColors[key]()
    end
  end
  refreshOriginalColors()

  local function isActive()
    return getIconDesaturated and getIconDesaturated() and lastUnreadCount == 0
  end

  local function update(unreadCount)
    lastUnreadCount = tonumber(unreadCount) or 0
    local desaturateEnabled = getIconDesaturated and getIconDesaturated()
    local shouldDesaturate = desaturateEnabled and lastUnreadCount == 0

    for key, tex in pairs(textures) do
      if tex.SetDesaturated then
        tex:SetDesaturated(shouldDesaturate)
      end
      if shouldDesaturate then
        applyVertexColor(tex, key == "background" and DESAT_BG or DESAT_GREY)
      else
        applyVertexColor(tex, originalColors[key])
      end
    end
  end

  local function refresh()
    update(lastUnreadCount)
  end

  return {
    update = update,
    refresh = refresh,
    isActive = isActive,
    refreshOriginalColors = refreshOriginalColors,
    DESAT_BG = DESAT_BG,
  }
end

ns.ToggleIconDesaturation = Desaturation
return Desaturation
