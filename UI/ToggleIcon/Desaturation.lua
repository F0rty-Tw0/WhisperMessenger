local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Desaturation = {}

local DESAT_GREY = { 0.45, 0.45, 0.45, 0.6 }
local DESAT_BG = { 0.25, 0.25, 0.25, 0.7 }
Desaturation.DESAT_GREY = DESAT_GREY

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
  local originalColors = {
    chatIcon = resolveColors.chatIcon(),
    background = resolveColors.background(),
    border = resolveColors.border(),
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
    local shouldDesaturate = paintsGrey()

    for _, tex in ipairs({ textures.chatIcon, textures.background, textures.border }) do
      -- wmAlwaysDesaturated: art grayed for good so a tint can color it
      if tex.SetDesaturated and not tex.wmAlwaysDesaturated then
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
    paintsGrey = paintsGrey,
    refreshOriginalColors = refreshOriginalColors,
    DESAT_BG = DESAT_BG,
  }
end

ns.ToggleIconDesaturation = Desaturation
return Desaturation
