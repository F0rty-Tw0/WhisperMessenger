local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Hides the own message preview after the player's chosen delay.
-- options: getSeconds, isShown, onExpire.
local PreviewAutoDismiss = {}

function PreviewAutoDismiss.New(options)
  local generation = 0
  local timer = nil
  local autoDismiss = {}

  function autoDismiss.cancel()
    generation = generation + 1
    -- Cancel the live timer instead of letting stale ones pile up under
    -- whisper bursts; the generation counter stays as a safety net for
    -- timers that cannot be cancelled (older stubs without Cancel).
    if timer ~= nil then
      if type(timer.Cancel) == "function" then
        pcall(timer.Cancel, timer)
      end
      timer = nil
    end
  end

  function autoDismiss.schedule()
    autoDismiss.cancel()
    local getter = options.getSeconds
    local seconds = (type(getter) == "function") and tonumber(getter()) or 0
    if not seconds or seconds <= 0 then
      return
    end
    local cTimer = _G.C_Timer
    if type(cTimer) ~= "table" or type(cTimer.NewTimer) ~= "function" then
      return
    end
    local scheduledGeneration = generation
    timer = cTimer.NewTimer(seconds, function()
      if scheduledGeneration ~= generation then
        return
      end
      if not options.isShown() then
        return
      end
      options.onExpire()
    end)
  end

  return autoDismiss
end

ns.ToggleIconPreviewAutoDismiss = PreviewAutoDismiss
return PreviewAutoDismiss
