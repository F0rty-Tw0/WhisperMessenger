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

  -- Reused across calls to avoid allocating a table 10x/sec on the alpha
  -- ticker; caller only reads the fields synchronously, never retains it.
  local alphaSettings = {}

  local function getAlphaSettings()
    alphaSettings.dimWhenMoving = settingsConfig.dimWhenMoving
    alphaSettings.windowOpacityActive = settingsConfig.windowOpacityActive
    alphaSettings.windowOpacityInactive = settingsConfig.windowOpacityInactive
    return alphaSettings
  end

  alphaController.hookScript(composerInput, "OnEditFocusGained", function()
    alphaController.refreshWindowAlpha(frame, composerInput, windowState, true, getAlphaSettings())
  end)

  alphaController.hookScript(composerInput, "OnEditFocusLost", function()
    alphaController.refreshWindowAlpha(frame, composerInput, windowState, false, getAlphaSettings())
  end)

  local function refreshWindowAlpha(forceOpaque)
    alphaController.refreshWindowAlpha(frame, composerInput, windowState, forceOpaque, getAlphaSettings())
  end

  return {
    refreshWindowAlpha = refreshWindowAlpha,
  }
end

ns.MessengerWindowWindowAlpha = WindowAlpha

return WindowAlpha
