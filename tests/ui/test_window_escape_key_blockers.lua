local FakeUI = require("tests.helpers.fake_ui")
local EscapeKey = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.EscapeKey")

-- The game's ESC list closes a dialog and cancels spell targeting before any
-- window. While either is up the focused messenger leaves ESC to the game.

local SAVED_NAMES = { "hooksecurefunc", "StaticPopup_OnShow", "StaticPopup_OnHide", "StaticPopup_ForEachShownDialog", "SpellIsTargeting" }

-- Runs fn(env) with a shown messenger and the game's dialog and targeting
-- API stubbed. env.bound lists the keys bound now; env.showDialog(dialog)
-- and env.hideDialog(dialog) go through the hooked StaticPopup functions;
-- env.targeting drives SpellIsTargeting; env.fire(event) runs OnEvent.
local function withWorld(fn)
  local saved = {}
  for _, name in ipairs(SAVED_NAMES) do
    saved[name] = rawget(_G, name)
  end
  local factory = FakeUI.NewFactory()
  local env = { bound = {}, dialogs = {}, targeting = false }
  -- Unhooked functions run nothing, like the game's own.
  local hooks = setmetatable({}, {
    __index = function()
      return function() end
    end,
  })
  rawset(_G, "StaticPopup_OnShow", function() end)
  rawset(_G, "StaticPopup_OnHide", function() end)
  rawset(_G, "hooksecurefunc", function(name, hook)
    hooks[name] = hook
  end)
  rawset(_G, "StaticPopup_ForEachShownDialog", function(callback)
    for _, dialog in ipairs(env.dialogs) do
      callback(dialog)
    end
  end)
  rawset(_G, "SpellIsTargeting", function()
    return env.targeting
  end)
  function env.showDialog(dialog)
    dialog:Show()
    table.insert(env.dialogs, dialog)
    hooks.StaticPopup_OnShow(dialog)
  end
  function env.hideDialog(dialog)
    dialog:Hide()
    env.dialogs = {}
    hooks.StaticPopup_OnHide(dialog)
  end
  function env.dialog(hideOnEscape)
    local dialog = factory.CreateFrame("Frame", nil, nil)
    dialog.hideOnEscape = hideOnEscape
    return dialog
  end

  local ok, err = pcall(function()
    env.window = factory.CreateFrame("Frame", "WhisperMessengerWindow", nil)
    env.window:Show()
    env.key = EscapeKey.New(env.window, {
      createFrame = function(...)
        env.button = factory.CreateFrame(...)
        return env.button
      end,
      getBindingKey = function()
        return "ESCAPE"
      end,
      inCombat = function()
        return false
      end,
      setOverrideBindingClick = function(_owner, _priority, key, _buttonName)
        table.insert(env.bound, key)
      end,
      clearOverrideBindings = function(_owner)
        env.bound = {}
      end,
    })
    function env.fire(event)
      env.button:GetScript("OnEvent")(env.button, event)
    end
    fn(env)
  end)
  for _, name in ipairs(SAVED_NAMES) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

return function()
  -- test_open_dialog_takes_the_escape_key_back
  withWorld(function(env)
    env.key.setFocused(true)
    env.showDialog(env.dialog(1))
    assert(#env.bound == 0, "ESC must close the open dialog, not the messenger")
  end)

  -- test_closed_dialog_gives_the_escape_key_back_to_the_messenger
  withWorld(function(env)
    env.key.setFocused(true)
    local dialog = env.dialog(1)
    env.showDialog(dialog)
    env.hideDialog(dialog)
    assert(#env.bound == 1, "once the dialog closes, ESC must close the messenger again")
  end)

  -- test_focus_while_dialog_open_leaves_escape_to_it
  withWorld(function(env)
    env.showDialog(env.dialog(1))
    env.key.setFocused(true)
    assert(#env.bound == 0, "a click on the messenger must not take ESC from an open dialog")
  end)

  -- test_dialog_escape_cannot_close_keeps_the_escape_key
  -- StaticPopup_EscapePressed closes only hideOnEscape dialogs.
  withWorld(function(env)
    env.key.setFocused(true)
    env.showDialog(env.dialog(nil))
    assert(#env.bound == 1, "a dialog ESC can't close must not take ESC from the messenger")
  end)

  -- test_spell_targeting_takes_the_escape_key_back
  withWorld(function(env)
    assert(env.button:IsEventRegistered("CURRENT_SPELL_CAST_CHANGED"), "targeting changes must reach the ESC button")
    env.key.setFocused(true)
    env.targeting = true
    env.fire("CURRENT_SPELL_CAST_CHANGED")
    assert(#env.bound == 0, "ESC must cancel spell targeting, not close the messenger")
    env.targeting = false
    env.fire("CURRENT_SPELL_CAST_CHANGED")
    assert(#env.bound == 1, "after targeting, ESC must close the messenger again")
  end)
end
