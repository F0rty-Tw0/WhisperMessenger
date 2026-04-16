local ReplyKeyBinder = require("WhisperMessenger.Core.Bootstrap.ReplyKeyBinder")

local function makeStubs()
  local created = {}
  local overrideBindings = {}
  local clearedFor = {}

  local frame = {
    _attrs = {},
    SetAttribute = function(self, key, value)
      self._attrs[key] = value
    end,
    GetAttribute = function(self, key)
      return self._attrs[key]
    end,
    RegisterForClicks = function(self, ...)
      self._clicks = { ... }
    end,
  }

  local createFrame = function(frameType, name, parent, template)
    frame.frameType = frameType
    frame.name = name
    frame.template = template
    table.insert(created, { frameType = frameType, name = name, template = template })
    return frame
  end

  local setOverride = function(owner, isPriority, key, buttonName)
    table.insert(overrideBindings, {
      owner = owner,
      isPriority = isPriority,
      key = key,
      buttonName = buttonName,
    })
  end

  local clearOverride = function(owner)
    table.insert(clearedFor, owner)
  end

  return {
    createFrame = createFrame,
    setOverride = setOverride,
    clearOverride = clearOverride,
    created = created,
    overrideBindings = overrideBindings,
    clearedFor = clearedFor,
    frame = frame,
  }
end

return function()
  -- -----------------------------------------------------------------------
  -- test_bind_creates_secure_action_button_with_wr_macro
  -- -----------------------------------------------------------------------
  do
    local stubs = makeStubs()
    local binder = ReplyKeyBinder.New({
      createFrame = stubs.createFrame,
      setOverrideBindingClick = stubs.setOverride,
      clearOverrideBindings = stubs.clearOverride,
      uiParent = { _name = "UIParent" },
    })

    binder.bind()

    assert(#stubs.created == 1, "expected exactly one frame creation, got " .. #stubs.created)
    local entry = stubs.created[1]
    assert(entry.frameType == "Button", "secure action button must be a Button frame")
    assert(entry.template == "SecureActionButtonTemplate", "must inherit SecureActionButtonTemplate")
    assert(stubs.frame:GetAttribute("type") == "macro", "secure action button must have type=macro attribute")
    assert(stubs.frame:GetAttribute("macrotext") == "/wr", "secure action button macrotext must be /wr")
    assert(
      stubs.frame._clicks ~= nil,
      "secure action button must call RegisterForClicks (required for override-binding dispatch)"
    )
    assert(
      stubs.frame._clicks[1] == "AnyDown",
      "must register for AnyDown — SetOverrideBindingClick dispatches on key-down; AnyUp would miss the click; both would double-fire"
    )
    assert(#stubs.overrideBindings == 1, "expected one override binding")
    local binding = stubs.overrideBindings[1]
    assert(binding.key == "R", "must override R key, got " .. tostring(binding.key))
    assert(binding.isPriority == true, "must use priority=true to beat user bindings")
    assert(binding.owner == stubs.frame, "owner of override binding must be our button")
  end

  -- -----------------------------------------------------------------------
  -- test_unbind_clears_override
  -- -----------------------------------------------------------------------
  do
    local stubs = makeStubs()
    local binder = ReplyKeyBinder.New({
      createFrame = stubs.createFrame,
      setOverrideBindingClick = stubs.setOverride,
      clearOverrideBindings = stubs.clearOverride,
      uiParent = { _name = "UIParent" },
    })

    binder.bind()
    binder.unbind()

    assert(#stubs.clearedFor == 1, "unbind must clear override bindings, got " .. #stubs.clearedFor)
    assert(stubs.clearedFor[1] == stubs.frame, "must clear bindings on our button")
  end

  -- -----------------------------------------------------------------------
  -- test_sync_binds_when_hide_from_default_chat_true
  -- -----------------------------------------------------------------------
  do
    local stubs = makeStubs()
    local settings = { hideFromDefaultChat = true }
    local binder = ReplyKeyBinder.New({
      createFrame = stubs.createFrame,
      setOverrideBindingClick = stubs.setOverride,
      clearOverrideBindings = stubs.clearOverride,
      uiParent = { _name = "UIParent" },
      getSettings = function()
        return settings
      end,
    })

    binder.sync()

    assert(#stubs.overrideBindings == 1, "sync with hide-whispers ON should bind")
    assert(#stubs.clearedFor == 0, "sync with hide-whispers ON should not unbind")
  end

  -- -----------------------------------------------------------------------
  -- test_sync_unbinds_when_hide_from_default_chat_false
  -- -----------------------------------------------------------------------
  do
    local stubs = makeStubs()
    local settings = { hideFromDefaultChat = true }
    local binder = ReplyKeyBinder.New({
      createFrame = stubs.createFrame,
      setOverrideBindingClick = stubs.setOverride,
      clearOverrideBindings = stubs.clearOverride,
      uiParent = { _name = "UIParent" },
      getSettings = function()
        return settings
      end,
    })

    binder.sync() -- binds
    settings.hideFromDefaultChat = false
    binder.sync() -- should unbind

    assert(#stubs.clearedFor >= 1, "sync with hide-whispers OFF should unbind")
  end

  -- -----------------------------------------------------------------------
  -- test_sync_stays_bound_in_mythic_when_hide_from_default_chat_on
  -- -----------------------------------------------------------------------
  -- We MUST keep R bound to our override even during M+ — Blizzard's
  -- default /r would crash on chatEditLastTell slots tainted by
  -- WhisperMessenger from pre-M+ filter-chain interactions. An always-
  -- bound override that opens our (composer-disabled) messenger is better
  -- than a guaranteed Lua error every R-press.
  do
    local stubs = makeStubs()
    local settings = { hideFromDefaultChat = true }
    local mythic = false
    local binder = ReplyKeyBinder.New({
      createFrame = stubs.createFrame,
      setOverrideBindingClick = stubs.setOverride,
      clearOverrideBindings = stubs.clearOverride,
      uiParent = { _name = "UIParent" },
      getSettings = function()
        return settings
      end,
      isMythic = function()
        return mythic
      end,
    })

    binder.sync()
    assert(#stubs.overrideBindings == 1, "should bind outside mythic")

    mythic = true
    binder.sync()

    assert(
      #stubs.clearedFor == 0,
      "sync must NOT unbind in Mythic+ — falling through to Blizzard /r crashes on pre-seeded taint"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_sync_idempotent_does_not_rebind_when_already_bound
  -- -----------------------------------------------------------------------
  do
    local stubs = makeStubs()
    local settings = { hideFromDefaultChat = true }
    local binder = ReplyKeyBinder.New({
      createFrame = stubs.createFrame,
      setOverrideBindingClick = stubs.setOverride,
      clearOverrideBindings = stubs.clearOverride,
      uiParent = { _name = "UIParent" },
      getSettings = function()
        return settings
      end,
    })

    binder.sync()
    binder.sync()
    binder.sync()

    assert(
      #stubs.overrideBindings == 1,
      "repeated sync while hide-whispers stays ON should not re-bind, got " .. #stubs.overrideBindings
    )
  end
end
