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

  local function getAlphaSettings()
    return {
      dimWhenMoving = settingsConfig.dimWhenMoving,
      windowOpacityActive = settingsConfig.windowOpacityActive,
      windowOpacityInactive = settingsConfig.windowOpacityInactive,
    }
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
