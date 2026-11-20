local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The message box's part of the gamepad UI. The input-scroll template's
-- scroll frame around the edit box is the D-pad stop: A on it puts the
-- cursor in the box, A again sends as Enter does. B takes the cursor out
-- before it goes on to close anything.
local GamepadComposer = {}

-- composer: Composer.Create's result. Returns the close order's
-- clearComposerFocus, or nil (and sets nothing) when the nav is inert or
-- the box has no scroll frame: the window then behaves as without a pad.
function GamepadComposer.Attach(nav, composer)
  local navActive = nav.isActive()

  if not navActive or composer == nil or composer.scroll == nil then
    return nil
  end
  local input = composer.input

  -- No check of its own: submit follows Enter's rules (disabled, empty,
  -- slash commands).
  local function onSmartNavClick()
    local hasFocus = input:HasFocus()

    if hasFocus then
      composer.submit()
    else
      input:SetFocus()
    end
  end

  -- Unlike Escape, B leaves a pending reply in place.
  local function clearComposerFocus()
    local hasFocus = input:HasFocus()

    if hasFocus then
      input:ClearFocus()

      return true
    end

    return false
  end

  -- A on a stop calls this field when it has one.
  composer.scroll.OnSmartNavClick = onSmartNavClick

  return clearComposerFocus
end

ns.MessengerWindowGamepadComposer = GamepadComposer

return GamepadComposer
