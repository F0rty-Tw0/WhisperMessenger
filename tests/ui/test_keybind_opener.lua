local KeybindOpener = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings.KeybindOpener")

-- "Set keybind…" opens the game's Key Bindings screen at our section: the
-- Settings panel where the flavor has one, the old KeyBindingFrame otherwise,
-- and nothing at all in combat.

local GLOBALS = { "Settings", "KeyBindingFrame_LoadUI", "KeyBindingFrame", "ShowUIPanel", "InCombatLockdown", "GetBindingKey", "GetBindingText" }

local function withGlobals(values, fn)
  local saved = {}
  for _, name in ipairs(GLOBALS) do
    saved[name] = rawget(_G, name)
    rawset(_G, name, values[name])
  end
  local ok, err = pcall(fn)
  for _, name in ipairs(GLOBALS) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

local function fakeSettings(calls)
  return {
    KEYBINDINGS_CATEGORY_ID = 42,
    OpenToCategory = function(categoryID, scrollTo)
      calls[#calls + 1] = { categoryID, scrollTo }
    end,
  }
end

return function()
  -- test_open_uses_settings_panel_scrolled_to_our_binding_section
  do
    local calls = {}
    withGlobals({ Settings = fakeSettings(calls) }, function()
      assert(KeybindOpener.Open() == true, "open should report success")
    end)
    assert(#calls == 1, "Settings.OpenToCategory should be called once")
    assert(calls[1][1] == 42, "should open the keybindings category")
    assert(calls[1][2] == "Whisper Messenger", "should scroll to the Bindings.xml category, got " .. tostring(calls[1][2]))
  end

  -- test_open_closes_messenger_window_before_opening
  do
    local order = {}
    local settings = {
      KEYBINDINGS_CATEGORY_ID = 1,
      OpenToCategory = function()
        order[#order + 1] = "open"
      end,
    }
    withGlobals({ Settings = settings }, function()
      KeybindOpener.Open(function()
        order[#order + 1] = "close"
      end)
    end)
    assert(order[1] == "close" and order[2] == "open", "window must close before the game screen opens")
  end

  -- test_open_falls_back_to_legacy_key_binding_frame
  do
    local shown = nil
    local frame = {}
    local values = {
      KeyBindingFrame_LoadUI = function()
        rawset(_G, "KeyBindingFrame", frame)
      end,
      ShowUIPanel = function(target)
        shown = target
      end,
    }
    withGlobals(values, function()
      assert(KeybindOpener.Open() == true, "legacy open should report success")
    end)
    assert(shown == frame, "legacy path should show KeyBindingFrame")
  end

  -- test_open_refused_in_combat
  do
    local calls = {}
    local closed = false
    withGlobals({
      Settings = fakeSettings(calls),
      InCombatLockdown = function()
        return true
      end,
    }, function()
      assert(KeybindOpener.Open(function()
        closed = true
      end) == false, "open must refuse in combat")
    end)
    assert(#calls == 0, "no game screen in combat")
    assert(closed == false, "window stays open when refused")
  end

  -- test_availability_reports_reason_per_state
  withGlobals({ Settings = fakeSettings({}) }, function()
    local enabled, reason = KeybindOpener.Availability()
    assert(enabled == true and reason == nil, "available out of combat")
  end)
  withGlobals({
    Settings = fakeSettings({}),
    InCombatLockdown = function()
      return true
    end,
  }, function()
    local enabled, reason = KeybindOpener.Availability()
    assert(enabled == false and reason == KeybindOpener.REASON_COMBAT, "combat reason expected, got " .. tostring(reason))
  end)
  withGlobals({}, function()
    local enabled, reason = KeybindOpener.Availability()
    assert(enabled == false and reason == KeybindOpener.REASON_UNSUPPORTED, "unsupported reason expected, got " .. tostring(reason))
    assert(KeybindOpener.Open() == false, "open must fail without any keybinding screen")
  end)

  -- test_current_keys_text_lists_display_names
  withGlobals({
    GetBindingKey = function(action)
      if action == "WHISPERMESSENGER_TOGGLE" then
        return "CTRL-O", "ALT-W"
      end
    end,
    GetBindingText = function(key)
      return "<" .. key .. ">"
    end,
  }, function()
    assert(KeybindOpener.CurrentKeysText() == "<CTRL-O>, <ALT-W>", "got " .. tostring(KeybindOpener.CurrentKeysText()))
  end)
  withGlobals({
    GetBindingKey = function() end,
  }, function()
    assert(KeybindOpener.CurrentKeysText() == nil, "unbound action has no key text")
  end)
end
