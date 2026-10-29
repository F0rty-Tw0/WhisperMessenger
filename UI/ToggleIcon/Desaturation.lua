local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Desaturation = {}

local DESAT_GREY = { 0.45, 0.45, 0.45, 0.6 }
local DESAT_BG = { 0.25, 0.25, 0.25, 0.7 }

function Desaturation.Create(deps)
  local textures = deps.textures
  local resolveColors = deps.resolveColors
  local getIconDesaturated = deps.getIconDesaturated
  local applyVertexColor = deps.applyVertexColor

  local lastUnreadCount = 0
  -- Snapshot original colors. Re-read on every theme refresh so preset
  -- switches propagate through the desaturate path.
  local originalColors = {
    chatIcon = resolveColors.chatIcon(),
    background = resolveColors.background(),
    border = resolveColors.border(),
  }

  local function isActive()
    return getIconDesaturated and getIconDesaturated() and lastUnreadCount == 0
  end

  local function update(unreadCount)
    lastUnreadCount = tonumber(unreadCount) or 0
    local desaturateEnabled = getIconDesaturated and getIconDesaturated()
    local shouldDesaturate = desaturateEnabled and lastUnreadCount == 0

    for _, tex in ipairs({ textures.chatIcon, textures.background, textures.border }) do
      if tex.SetDesaturated then
        tex:SetDesaturated(shouldDesaturate)
      end
    end

    if shouldDesaturate then
      applyVertexColor(textures.chatIcon, DESAT_GREY)
      applyVertexColor(textures.background, DESAT_BG)
      applyVertexColor(textures.border, DESAT_GREY)
    else
      applyVertexColor(textures.chatIcon, originalColors.chatIcon)
      applyVertexColor(textures.background, originalColors.background)
      applyVertexColor(textures.border, originalColors.border)
    end
  end

  local function refresh()
    update(lastUnreadCount)
  end

  local function refreshOriginalColors()
    originalColors.chatIcon = resolveColors.chatIcon()
    originalColors.background = resolveColors.background()
    originalColors.border = resolveColors.border()
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
