local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Our popups in the WoW: Forever gamepad UI, for GamepadNav: shown → the
-- game focuses the popup and remembers the control to return to; hidden →
-- focus goes back there. Asked for in combat → done when combat ends; a
-- popup shown and hidden within one combat leaves no trace.
local GamepadPopups = {}

local function noop() end

local function weakMap()
  return setmetatable({}, { __mode = "k" })
end

-- FrameShown marks an added popup in isPopupFrame (FrameControlsManager.lua
-- #L411-L414) and FrameHidden clears it (#L494-L496). A client without the
-- field: assume it took the popup.
local function heldBy(fcm, popup)
  local popupFrames = fcm.isPopupFrame
  return type(popupFrames) ~= "table" or popupFrames[popup] == true
end

-- deps: fcm (GamepadMode.FrameControlsManager), inCombat. A client
-- without HandlePopupShown gets methods that do nothing.
function GamepadPopups.New(deps)
  local fcm, inCombat = deps.fcm, deps.inCombat
  if type(fcm.HandlePopupShown) ~= "function" then
    return { popupShown = noop, popupHidden = noop, setPopupCloseHandler = noop, settle = noop }
  end
  -- HandlePopupShown returns nothing and refuses the popup while the gamepad
  -- UI is off: "listed" is our own record of what it took.
  local listed, pending, handlers = weakMap(), weakMap(), weakMap()
  local order = {}

  -- The last ask per popup wins; settle skips the repeats in order.
  local function queue(popup, what)
    table.insert(order, popup)
    pending[popup] = what
  end

  local function hide(popup)
    if listed[popup] then
      fcm:FrameHidden(popup)
      listed[popup] = nil
    end
  end

  local function show(popup)
    -- A stale entry is never refocused: let it go first.
    hide(popup)
    fcm:HandlePopupShown(popup)
    listed[popup] = heldBy(fcm, popup) or nil
  end

  local popups = {}

  function popups.popupShown(popup)
    if inCombat() then
      queue(popup, "show")
      return
    end
    pending[popup] = nil
    show(popup)
  end

  function popups.popupHidden(popup)
    if inCombat() then
      -- Not listed yet: settle has nothing to hide, so show + hide cancel.
      queue(popup, "hide")
      return
    end
    -- A "show" still queued finds the popup hidden at settle: nothing to do.
    hide(popup)
  end

  -- B on the focused popup runs fn(); true tells the game it was handled.
  -- Set once per popup. A plain field on our own frame: fine in combat.
  function popups.setPopupCloseHandler(popup, fn)
    if handlers[popup] then
      return
    end
    handlers[popup] = true
    popup.SmartNavigationCloseHandler = function()
      return fn()
    end
  end

  -- Out of combat only: each popup asked for meanwhile, in the order asked.
  function popups.settle()
    local asked = order
    order = {}
    for _, popup in ipairs(asked) do
      local what = pending[popup]
      pending[popup] = nil
      if what ~= nil then
        hide(popup)
        if what == "show" and popup:IsShown() then
          show(popup)
        end
      end
    end
  end

  return popups
end

ns.MessengerWindowGamepadPopups = GamepadPopups

return GamepadPopups
