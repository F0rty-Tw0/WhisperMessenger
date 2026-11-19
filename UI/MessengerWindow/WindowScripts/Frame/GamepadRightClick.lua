local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The X button's right-click for GamepadNav: one Blizzard prompted binding
-- (X → SmartNavigation:RightClick on the focused target) usable only on
-- targets carrying our buttonContext, in a footer on the window. Built on
-- the first show; show/hide switch the footer's bindings on and off.
-- GamepadNav calls show only out of combat.
local GamepadRightClick = {}

-- deps: sharedUtility (GamepadSharedUtility), key (GAMEPAD_FACE_LEFT),
-- onlyIfUsable (PromptedBindingMixin.VISIBILITY_TYPE.ONLY_IF_USABLE),
-- smartNavigation. Without the shared utility, show does nothing.
function GamepadRightClick.New(frame, deps)
  local context, label
  local footer
  local shown = false

  local function build()
    local util = deps.sharedUtility
    if type(util) ~= "table" or type(util.CreatePromptedBinding) ~= "function" or type(util.CreatePromptedBindingFooter) ~= "function" then
      return nil
    end
    local binding = util.CreatePromptedBinding(deps.key, function()
      deps.smartNavigation:RightClick()
    end, label, "WhisperMessengerRightClick")
    -- ALWAYS (the default) would keep X bound where it does nothing.
    if deps.onlyIfUsable ~= nil then
      binding:SetVisibilityType(deps.onlyIfUsable)
    end
    binding:AddButtonContext(context)
    local built = util.CreatePromptedBindingFooter(frame, "WhisperMessengerFooter")
    built:AddPromptedBinding(binding)
    built:Finalize()
    return built
  end

  local rightClick = {}

  -- The first call wins; returns true for it.
  function rightClick.bind(buttonContext, text)
    if context ~= nil then
      return false
    end
    context, label = buttonContext, text
    return true
  end

  function rightClick.show()
    if context == nil or shown then
      return
    end
    footer = footer or build()
    if footer then
      shown = true
      footer:ShowAndActivateBindings()
    end
  end

  function rightClick.hide()
    if not shown then
      return
    end
    shown = false
    footer:HideAndDeactivateBindings()
  end

  return rightClick
end

ns.MessengerWindowGamepadRightClick = GamepadRightClick

return GamepadRightClick
