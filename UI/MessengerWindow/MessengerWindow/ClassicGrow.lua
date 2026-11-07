local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local WindowGrowAnimation = ns.MessengerWindowWindowGrowAnimation
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGrowAnimation")

-- The classic window grows out of its icon on show and shrinks into it on
-- hide. Hooks (not scripts): the window's own OnShow/OnHide stay in place.
local ClassicGrow = {}

local function noSource()
  return nil
end

local function alwaysOn()
  return true
end

-- options: factory, parent, theme, windowAlpha, getSource(), isOn().
function ClassicGrow.Attach(frame, options)
  local getSource = options.getSource or noSource
  local isOn = options.isOn or alwaysOn
  local windowAlpha = options.windowAlpha
  local anim = WindowGrowAnimation.Attach(frame, {
    factory = options.factory,
    parent = options.parent,
    theme = options.theme,
    setAlphaHeld = windowAlpha.setHeld,
    refreshAlpha = function()
      windowAlpha.refreshWindowAlpha(true)
    end,
  })

  local open = false
  -- The icon the last grow came from; a close shrinks back into it while it is still shown.
  local remembered = nil

  frame:HookScript("OnShow", function()
    if open then
      return
    end
    open = true
    remembered = isOn() and getSource() or nil
    if remembered then
      anim.play(anim.beginOpen(remembered))
      return
    end
    anim.finish()
  end)

  frame:HookScript("OnHide", function()
    -- The parent hid (Alt+Z): the window is still open.
    if frame:IsShown() then
      return
    end
    -- Hidden before its first open (right after Create): no shrink.
    if not open then
      return
    end
    open = false
    local source = nil
    if isOn() then
      source = (remembered and remembered:IsVisible()) and remembered or getSource()
    end
    if source then
      anim.play(anim.beginClose(source))
      return
    end
    anim.finish()
  end)
end

ns.MessengerWindowClassicGrow = ClassicGrow

return ClassicGrow
