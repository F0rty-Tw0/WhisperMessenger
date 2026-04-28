local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")

local AlphaController = {}

function AlphaController.getAlpha(target, fallback)
  if target and type(target.GetAlpha) == "function" then
    local value = target:GetAlpha()
    if type(value) == "number" then
      return value
    end
  end
  if target and type(target.alpha) == "number" then
    return target.alpha
  end
  return fallback
end

function AlphaController.hookScript(target, eventName, handler)
  if target == nil or type(target.SetScript) ~= "function" then
    return
  end
  local previous = target.GetScript and target:GetScript(eventName) or nil
  if previous == nil then
    target:SetScript(eventName, handler)
    return
  end
  target:SetScript(eventName, function(...)
    previous(...)
    handler(...)
  end)
end

-- frame: the window frame
-- composerInput: composer.input widget
function AlphaController.isWindowEngaged(frame, composerInput)
  if composerInput and type(composerInput.HasFocus) == "function" and composerInput:HasFocus() then
    return true
  end
  if frame and type(frame.IsMouseOver) == "function" and frame:IsMouseOver() then
    return true
  end
  return false
end

-- In 12.0 Midnight, `GetUnitSpeed` / `IsMouselooking` / `IsMouseButtonDown`
-- can return "secret" values when our execution is tainted — any arithmetic
-- comparison or boolean test on the result raises. Wrap the probe *inside*
-- pcall so the error is caught at its source; a raw `pcall(fn)` would return
-- the secret value unchanged and crash at the caller.
local function probeIsMoving()
  if type(_G.GetUnitSpeed) ~= "function" then
    return false
  end
  local ok, moving = pcall(function()
    local speed = _G.GetUnitSpeed("player")
    return type(speed) == "number" and speed > 0
  end)
  return ok and moving == true
end

local function probeBoolean(fn)
  if type(fn) ~= "function" then
    return false
  end
  local ok, value = pcall(function()
    return fn() == true
  end)
  return ok and value == true
end

function AlphaController.isExternalActivityActive()
  if probeIsMoving() then
    return true
  end
  if probeBoolean(_G.IsMouselooking) then
    return true
  end
  if probeBoolean(_G.IsMouseButtonDown) then
    return true
  end
  return false
end

-- windowState: table with a `isDimmed` boolean field (mutated in place)
-- alphaConfig (optional): { active = number, inactive = number }
function AlphaController.applyWindowAlpha(frame, dimmed, windowState, alphaConfig)
  if frame == nil then
    return
  end
  local activeAlpha = alphaConfig and alphaConfig.active or Theme.WINDOW_IDLE_ALPHA
  local inactiveAlpha = alphaConfig and alphaConfig.inactive or Theme.WINDOW_EXTERNAL_ACTIVITY_ALPHA
  local targetAlpha = dimmed and inactiveAlpha or activeAlpha
  local currentAlpha = AlphaController.getAlpha(frame, activeAlpha)
  if currentAlpha == targetAlpha and windowState.isDimmed == dimmed then
    return
  end
  if frame.SetAlpha then
    frame:SetAlpha(targetAlpha)
  else
    frame.alpha = targetAlpha
  end
  windowState.isDimmed = dimmed
end

-- settings (optional): { dimWhenMoving, windowOpacityActive, windowOpacityInactive }
function AlphaController.refreshWindowAlpha(frame, composerInput, windowState, forceOpaque, settings)
  local alphaConfig = settings and { active = settings.windowOpacityActive, inactive = settings.windowOpacityInactive } or nil
  if forceOpaque == true then
    AlphaController.applyWindowAlpha(frame, false, windowState, alphaConfig)
    return
  end
  if settings and settings.dimWhenMoving == false then
    AlphaController.applyWindowAlpha(frame, false, windowState, alphaConfig)
    return
  end
  AlphaController.applyWindowAlpha(
    frame,
    (not AlphaController.isWindowEngaged(frame, composerInput)) and AlphaController.isExternalActivityActive(),
    windowState,
    alphaConfig
  )
end

ns.MessengerWindowAlphaController = AlphaController

return AlphaController
