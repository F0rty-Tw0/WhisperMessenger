-- Fake prompted bindings for FakeGamepad: GamepadSharedUtility's
-- CreatePromptedBinding / CreatePromptedBindingFooter, PromptedBindingMixin
-- SmartNavigation:RightClick, GetCurrentButton and GetActiveFrame. Mirrors PromptedBinding.lua#L703-L725
-- (key, function, label; button contexts; visibility type),
-- PromptedBindingFooter.lua#L366-L392 (show/hide idempotent through
-- isShown) and SmartNavigation.lua#L1655-L1659 (right-click = mouse down,
-- then up, with "RightButton").
local FakeGamepadBindings = {}

-- env: the FakeGamepad env; log(name, ...) records a call; smartNav: the
-- fake SmartNavigation, which gains RightClick.
function FakeGamepadBindings.Install(env, log, smartNav)
  env.FACE_LEFT = "PAD3"
  env.ONLY_IF_USABLE = 2
  env.bindings, env.footers = {}, {}
  env.promptedBindingMixin = { VISIBILITY_TYPE = { ALWAYS = 1, ONLY_IF_USABLE = 2, NEVER = 3 } }

  local sharedUtility = {}
  function sharedUtility.CreatePromptedBinding(key, fn, label, debugName)
    log("CreatePromptedBinding", key, label, debugName)
    local binding = { key = key, fn = fn, label = label, contexts = {}, visibility = env.promptedBindingMixin.VISIBILITY_TYPE.ALWAYS }
    function binding:AddButtonContext(name)
      table.insert(self.contexts, name)
    end
    function binding:SetVisibilityType(visibility)
      self.visibility = visibility
    end
    table.insert(env.bindings, binding)
    return binding
  end
  function sharedUtility.CreatePromptedBindingFooter(parent, debugName)
    log("CreatePromptedBindingFooter", parent, debugName)
    local footer = { parent = parent, bindings = {}, finalized = false, shown = false }
    function footer:AddPromptedBinding(binding)
      table.insert(self.bindings, binding)
    end
    function footer:Finalize()
      self.finalized = true
    end
    function footer:ShowAndActivateBindings()
      log("ShowAndActivateBindings", self)
      self.shown = true
    end
    function footer:HideAndDeactivateBindings()
      log("HideAndDeactivateBindings", self)
      self.shown = false
    end
    table.insert(env.footers, footer)
    return footer
  end
  env.sharedUtility = sharedUtility

  -- MouseUp on a Button fires its OnClick with the same button.
  function smartNav:RightClick()
    log("RightClick")
    local button = env.currentButton
    for _, name in ipairs({ "OnMouseDown", "OnMouseUp", "OnClick" }) do
      local script = button and button.GetScript and button:GetScript(name)
      if script then
        script(button, "RightButton")
      end
    end
  end

  -- SmartNavigation's getters for the pad cursor's button and its frame.
  function smartNav:GetCurrentButton()
    return env.currentButton
  end
  function smartNav:GetActiveFrame()
    return env.activeFrame
  end

  -- The pad cursor on frame, inside activeFrame (the game's active frame).
  function env.focus(frame, activeFrame)
    env.currentButton = frame
    env.activeFrame = activeFrame
  end

  -- The game right-clicking target, as SmartNavigation:RightClick does on
  -- the focused button.
  function env.rightClick(target)
    env.currentButton = target
    smartNav:RightClick()
  end

  -- X pressed with target focused: true when a shown footer's X binding
  -- is usable there (its contexts hold target.buttonContext) and ran.
  function env.pressX(target)
    env.currentButton = target
    for _, footer in ipairs(env.footers) do
      if footer.shown then
        for _, binding in ipairs(footer.bindings) do
          for _, context in ipairs(binding.key == env.FACE_LEFT and binding.contexts or {}) do
            if target.buttonContext ~= nil and context == target.buttonContext then
              binding.fn(true)
              return true
            end
          end
        end
      end
    end
    return false
  end
end

return FakeGamepadBindings
