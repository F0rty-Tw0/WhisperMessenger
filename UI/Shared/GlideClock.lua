local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local mathMin = math.min

-- One eased clock on a frame's OnUpdate, shared by every glide and grow.
local GlideClock = {}

-- Longest step the clock takes in one frame. Opening a window does its heavy
-- refresh just as the animation starts; a slow frame then pauses it instead
-- of skipping most of it.
local MAX_STEP = 1 / 30

local function easeOut(t)
  local inverse = 1 - t
  return 1 - inverse * inverse * inverse
end

-- onTick(t, p): linear time and eased path, both under 1. The end belongs to
-- onDone (optional), called once after the script is cleared. A new Run on the
-- same frame replaces the old one.
function GlideClock.Run(frame, duration, onTick, onDone)
  local elapsed = 0
  frame:SetScript("OnUpdate", function(_self, delta)
    elapsed = elapsed + mathMin(delta, MAX_STEP)
    if elapsed >= duration then
      frame:SetScript("OnUpdate", nil)
      if onDone then
        onDone()
      end
      return
    end
    local t = elapsed / duration
    onTick(t, easeOut(t))
  end)
end

-- Never calls onDone.
function GlideClock.Stop(frame)
  frame:SetScript("OnUpdate", nil)
end

ns.GlideClock = GlideClock

return GlideClock
