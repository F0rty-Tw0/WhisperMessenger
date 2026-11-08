local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Hides the own message preview after the player's chosen delay.
-- options: getSeconds, isShown, onExpire.
local PreviewAutoDismiss = {}

local HOVER = "hover"

function PreviewAutoDismiss.New(options)
  local generation = 0
  local timer = nil
  -- Why the timer waits ("focus", "hover"). A delay asked for meanwhile
  -- starts over in full once every hold has ended.
  local holds = {}
  local pending = false
  local autoDismiss = {}

  local function isHeld()
    return next(holds) ~= nil
  end

  local function stopTimer()
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

  local function start()
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
      timer = nil
      if not options.isShown() then
        return
      end
      options.onExpire()
    end)
  end

  function autoDismiss.cancel()
    pending = false
    stopTimer()
  end

  function autoDismiss.schedule()
    autoDismiss.cancel()
    if isHeld() then
      pending = true
      return
    end
    start()
  end

  function autoDismiss.setHeld(reason, held)
    if held then
      if holds[reason] then
        return
      end
      holds[reason] = true
      if timer ~= nil then
        stopTimer()
        pending = true
      end
      return
    end
    if not holds[reason] then
      return
    end
    holds[reason] = nil
    if pending and not isHeld() then
      pending = false
      start()
    end
  end

  return autoDismiss
end

-- The cursor over the card holds the timer. Moving onto a child (the reply
-- box, the x) fires the card's OnLeave too, so the hold ends only once a
-- poll finds the cursor off the card and everything on it.
function PreviewAutoDismiss.HoldWhileHovered(frame, autoDismiss)
  local function release()
    frame:SetScript("OnUpdate", nil)
    autoDismiss.setHeld(HOVER, false)
  end
  local function poll(self)
    if not self:IsMouseOver() then
      release()
    end
  end
  frame:SetScript("OnEnter", function()
    autoDismiss.setHeld(HOVER, true)
    frame:SetScript("OnUpdate", poll)
  end)
  -- A hidden frame gets no OnUpdate: the poll would never end the hold.
  frame:HookScript("OnHide", release)
end

ns.ToggleIconPreviewAutoDismiss = PreviewAutoDismiss
return PreviewAutoDismiss
