local ReplyKeyBinder = require("WhisperMessenger.Core.Bootstrap.ReplyKeyBinder")

-- Default stub: REPLY bound to "R" (Blizzard default). Tests override as needed.
local function defaultGetBindingKey(action)
  if action == "REPLY" then
    return "R"
  end
  return nil
end

local function makeStubs(getBindingKey)
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
    getBindingKey = getBindingKey or defaultGetBindingKey,
    created = created,
    overrideBindings = overrideBindings,
    clearedFor = clearedFor,
    frame = frame,
  }
end

local function newBinder(stubs, extra)
  local deps = {
    createFrame = stubs.createFrame,
    setOverrideBindingClick = stubs.setOverride,
    clearOverrideBindings = stubs.clearOverride,
    getBindingKey = stubs.getBindingKey,
    uiParent = { _name = "UIParent" },
  }
  if extra then
    for k, v in pairs(extra) do
      deps[k] = v
    end
  end
  return ReplyKeyBinder.New(deps)
end

return function()
  -- -----------------------------------------------------------------------
  -- test_bind_creates_secure_action_button_with_wr_macro
  -- -----------------------------------------------------------------------
  do
    local stubs = makeStubs()
    local binder = newBinder(stubs)

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
    assert(binding.key == "R", "must override R key (default REPLY binding), got " .. tostring(binding.key))
    assert(binding.isPriority == true, "must use priority=true to beat user bindings")
    assert(binding.owner == stubs.frame, "owner of override binding must be our button")
  end

  -- -----------------------------------------------------------------------
  -- test_bind_uses_user_reply_binding_not_hardcoded_r
  -- -----------------------------------------------------------------------
  -- The user may have rebound REPLY to something other than R (e.g. because
  -- R is bound to an ability). Respect GetBindingKey("REPLY") instead of
  -- hardcoding R — otherwise we steal a keystroke they assigned to a skill.
  do
    local stubs = makeStubs(function(action)
      if action == "REPLY" then
        return "T"
      end
      return nil
    end)
    local binder = newBinder(stubs)

    binder.bind()

    assert(#stubs.overrideBindings == 1, "expected one override binding, got " .. #stubs.overrideBindings)
    assert(
      stubs.overrideBindings[1].key == "T",
      "must override user-bound REPLY key 'T', got " .. tostring(stubs.overrideBindings[1].key)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_bind_overrides_all_keys_bound_to_reply
  -- -----------------------------------------------------------------------
  -- WoW lets users bind up to two keys per action. GetBindingKey returns
  -- each slot as an additional return value. Override all of them.
  do
    local stubs = makeStubs(function(action)
      if action == "REPLY" then
        return "R", "NUMPAD0"
      end
      return nil
    end)
    local binder = newBinder(stubs)

    binder.bind()

    assert(
      #stubs.overrideBindings == 2,
      "expected two override bindings (one per REPLY slot), got " .. #stubs.overrideBindings
    )
    local seen = {}
    for _, b in ipairs(stubs.overrideBindings) do
      seen[b.key] = true
    end
    assert(seen["R"], "must override R slot")
    assert(seen["NUMPAD0"], "must override NUMPAD0 slot")
  end

  -- -----------------------------------------------------------------------
  -- test_bind_skips_when_reply_unbound
  -- -----------------------------------------------------------------------
  -- If the user unbound REPLY entirely, we must not grab a random key —
  -- there's nothing to override. Respect their choice and skip.
  do
    local stubs = makeStubs(function()
      return nil
    end)
    local binder = newBinder(stubs)

    binder.bind()

    assert(#stubs.overrideBindings == 0, "must not bind any key when REPLY is unbound, got " .. #stubs.overrideBindings)
    assert(binder.isBound() == false, "isBound() must report false when REPLY is unbound")
  end

  -- -----------------------------------------------------------------------
  -- test_bind_ignores_empty_string_keys
  -- -----------------------------------------------------------------------
  -- Defensive: if GetBindingKey returns "" in a slot, treat as unbound.
  do
    local stubs = makeStubs(function(action)
      if action == "REPLY" then
        return "", "R"
      end
      return nil
    end)
    local binder = newBinder(stubs)

    binder.bind()

    assert(#stubs.overrideBindings == 1, "empty-string slots must be skipped, got " .. #stubs.overrideBindings)
    assert(stubs.overrideBindings[1].key == "R", "expected R, got " .. tostring(stubs.overrideBindings[1].key))
  end

  -- -----------------------------------------------------------------------
  -- test_unbind_clears_override
  -- -----------------------------------------------------------------------
  do
    local stubs = makeStubs()
    local binder = newBinder(stubs)

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
    local binder = newBinder(stubs, {
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
    local binder = newBinder(stubs, {
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
    local binder = newBinder(stubs, {
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
  -- test_sync_idempotent_when_reply_key_unchanged
  -- -----------------------------------------------------------------------
  do
    local stubs = makeStubs()
    local settings = { hideFromDefaultChat = true }
    local binder = newBinder(stubs, {
      getSettings = function()
        return settings
      end,
    })

    binder.sync()
    binder.sync()
    binder.sync()

    assert(
      #stubs.overrideBindings == 1,
      "repeated sync while REPLY binding unchanged should not re-bind, got " .. #stubs.overrideBindings
    )
  end

  -- -----------------------------------------------------------------------
  -- test_sync_rebinds_when_user_changes_reply_key
  -- -----------------------------------------------------------------------
  -- If the user opens the keybindings UI and changes REPLY from R to T,
  -- the next sync must clear the stale R override and install T.
  do
    local replyKey = "R"
    local stubs = makeStubs(function(action)
      if action == "REPLY" then
        return replyKey
      end
      return nil
    end)
    local settings = { hideFromDefaultChat = true }
    local binder = newBinder(stubs, {
      getSettings = function()
        return settings
      end,
    })

    binder.sync()
    assert(stubs.overrideBindings[1].key == "R", "first sync binds R")

    replyKey = "T"
    binder.sync()

    assert(#stubs.clearedFor >= 1, "rebinding must clear the prior override before applying the new key")
    local last = stubs.overrideBindings[#stubs.overrideBindings]
    assert(last.key == "T", "post-rebind override must target new key T, got " .. tostring(last.key))
  end

  -- -----------------------------------------------------------------------
  -- test_sync_unbinds_when_user_clears_reply_binding
  -- -----------------------------------------------------------------------
  do
    local replyKey = "R"
    local stubs = makeStubs(function(action)
      if action == "REPLY" and replyKey then
        return replyKey
      end
      return nil
    end)
    local settings = { hideFromDefaultChat = true }
    local binder = newBinder(stubs, {
      getSettings = function()
        return settings
      end,
    })

    binder.sync()
    assert(binder.isBound() == true, "bound after first sync")

    replyKey = nil
    binder.sync()

    assert(binder.isBound() == false, "sync must unbind when user clears REPLY")
    assert(#stubs.clearedFor >= 1, "must clear the stale override")
  end
end
