local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local WindowAlpha = {}

function WindowAlpha.Create(options)
  options = options or {}

  local alphaController = options.alphaController
  local frame = options.frame
  local composerInput = options.composerInput
  local settingsConfig = options.settingsConfig or {}

  local windowState = { isDimmed = false }
  -- The opening animation owns the alpha while held: the 10-a-second ticker
  -- and focus changes would otherwise pop the window through it.
  local held = false

  -- Reused across calls to avoid allocating a table 10x/sec on the alpha
  -- ticker; caller only reads the fields synchronously, never retains it.
  local alphaSettings = {}

  local function getAlphaSettings()
    alphaSettings.dimWhenMoving = settingsConfig.dimWhenMoving
    alphaSettings.windowOpacityActive = settingsConfig.windowOpacityActive
    alphaSettings.windowOpacityInactive = settingsConfig.windowOpacityInactive
    return alphaSettings
  end

  local function refreshWindowAlpha(forceOpaque)
    if held then
      return
    end
    alphaController.refreshWindowAlpha(frame, composerInput, windowState, forceOpaque, getAlphaSettings())
  end

  alphaController.hookScript(composerInput, "OnEditFocusGained", function()
    refreshWindowAlpha(true)
  end)

  alphaController.hookScript(composerInput, "OnEditFocusLost", function()
    refreshWindowAlpha(false)
  end)

  return {
    refreshWindowAlpha = refreshWindowAlpha,
    setHeld = function(nextHeld)
      held = nextHeld == true
    end,
  }
end

ns.MessengerWindowWindowAlpha = WindowAlpha

return WindowAlpha
