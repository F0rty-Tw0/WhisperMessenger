local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Desaturation = {}

local DESAT_GREY = { 0.45, 0.45, 0.45, 0.6 }
local DESAT_BG = { 0.25, 0.25, 0.25, 0.7 }
Desaturation.DESAT_GREY = DESAT_GREY
-- The back bubble's idle gray on the circle: opaque, so it reads over the dark circle.
Desaturation.DESAT_BACK = { 0.55, 0.55, 0.55, 1 }

-- deps.textures, resolveColors, applyVertexColor and keepColors are optional:
-- without textures this only tracks the unread count for isActive() and paints
-- nothing.
function Desaturation.Create(deps)
  local textures = deps.textures
  local resolveColors = deps.resolveColors
  local getIconDesaturated = deps.getIconDesaturated
  local applyVertexColor = deps.applyVertexColor
  -- keepColors(): true while the look grays out only its accent bubble
  -- (square look), so these textures keep their colors.
  local keepColors = deps.keepColors

  local lastUnreadCount = 0
  -- Snapshot original colors. Re-read on every theme refresh so preset
  -- switches propagate through the desaturate path.
  local originalColors = textures and {
    chatIcon = resolveColors.chatIcon(),
    background = resolveColors.background(),
  }

  local function isActive()
    return getIconDesaturated and getIconDesaturated() and lastUnreadCount == 0
  end

  -- True while these textures are painted gray (idle and not keepColors).
  local function paintsGrey()
    return isActive() and not (keepColors and keepColors())
  end

  local function update(unreadCount)
    lastUnreadCount = tonumber(unreadCount) or 0
    if not textures then
      return
    end
    local shouldDesaturate = paintsGrey()

    for _, tex in ipairs({ textures.chatIcon, textures.background }) do
      if tex.SetDesaturated then
        tex:SetDesaturated(shouldDesaturate)
      end
    end

    if shouldDesaturate then
      applyVertexColor(textures.chatIcon, DESAT_GREY)
      applyVertexColor(textures.background, DESAT_BG)
    else
      applyVertexColor(textures.chatIcon, originalColors.chatIcon)
      applyVertexColor(textures.background, originalColors.background)
    end
  end

  local function refresh()
    update(lastUnreadCount)
  end

  local function refreshOriginalColors()
    if not textures then
      return
    end
    originalColors.chatIcon = resolveColors.chatIcon()
    originalColors.background = resolveColors.background()
  end

  return {
    update = update,
    refresh = refresh,
    isActive = isActive,
    refreshOriginalColors = refreshOriginalColors,
  }
end

ns.ToggleIconDesaturation = Desaturation
return Desaturation
