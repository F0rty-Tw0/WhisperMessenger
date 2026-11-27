local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local GamepadDeps = ns.MessengerWindowGamepadDeps or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadDeps")

-- X on the pad opens WM's right-click menu for the contact row, message or
-- chat header under the pad cursor. Our own frame hears the button: a
-- prompted binding or a buttonContext on our frames tainted the game's
-- gamepad UI (#320). The frame never swallows input (propagation stays on),
-- so A, B and the D-pad still reach the game.
local GamepadMenuButton = {}

local REGEN_ENABLED = "PLAYER_REGEN_ENABLED"

local function xKey()
  return _G.GAMEPAD_FACE_LEFT or "PAD3"
end

-- Both calls can be blocked in combat, so they run once combat is over.
local function turnOn(listener, inCombat, after)
  local function try()
    if inCombat() then
      after(0, try)
      return
    end
    listener:SetPropagateKeyboardInput(true)
    listener:EnableGamePadButton(true)
  end
  if not inCombat() then
    try()
    return
  end
  listener:RegisterEvent(REGEN_ENABLED)
  listener:SetScript("OnEvent", function(self)
    self:UnregisterEvent(REGEN_ENABLED)
    try()
  end)
end

-- nav: the window's GamepadNav. frame: the messenger window, the
-- listener's parent. deps (tests): createFrame, inCombat, after,
-- usesOwnMenus; default to the game's.
function GamepadMenuButton.Attach(nav, frame, deps)
  if not nav.isActive() then
    return
  end
  deps = deps or {}
  local createFrame = deps.createFrame
    or function()
      local create = _G.CreateFrame
      return type(create) == "function" and create("Frame", nil, frame) or nil
    end
  local usesOwnMenus = deps.usesOwnMenus or FlavorCompat.UsesOwnMenus
  local listener = createFrame()
  if not listener or not listener.EnableGamePadButton or not listener.SetPropagateKeyboardInput then
    return
  end
  -- Combat, the active frame and a hidden button are currentStop's checks.
  listener:SetScript("OnGamePadButtonDown", function(_self, key)
    if key ~= xKey() or not usesOwnMenus() then
      return
    end
    local stop = nav.currentStop()
    if stop and stop._wmOpenMenu then
      stop._wmOpenMenu(stop)
    end
  end)
  turnOn(listener, deps.inCombat or GamepadDeps.defaultInCombat, deps.after or GamepadDeps.defaultAfter)
end

ns.MessengerWindowGamepadMenuButton = GamepadMenuButton

return GamepadMenuButton
