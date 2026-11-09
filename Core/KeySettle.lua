local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local KeySettle = {}

-- A key press runs its action on key-down; the key's character event reaches
-- whatever has focus during the next frame's input phase, after that frame's
-- C_Timer callbacks. Waiting one frame plus a short delay (What The Whisper
-- uses the same 0.05s) keeps the composer unfocused until the letter is gone.
KeySettle.SETTLE_SECONDS = 0.05

function KeySettle.After(fn)
  local timer = _G.C_Timer
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    fn()
    return
  end
  timer.After(0, function()
    timer.After(KeySettle.SETTLE_SECONDS, fn)
  end)
end

ns.KeySettle = KeySettle

return KeySettle
