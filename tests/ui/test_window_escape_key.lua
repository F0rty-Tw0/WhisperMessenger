local FakeUI = require("tests.helpers.fake_ui")
local EscapeKey = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.EscapeKey")

-- Builds an EscapeKey for a shown window with recorded binding calls.
-- env.combat drives InCombatLockdown; env.bound lists the keys bound now.
-- makeParent(factory), optional, builds the window's parent.
local function newEnv(makeParent)
  local factory = FakeUI.NewFactory()
  local env = { combat = false, bound = {}, blocked = 0 }
  local parent = makeParent and makeParent(factory) or nil
  env.window = factory.CreateFrame("Frame", "WhisperMessengerWindow", parent)
  env.window:Show()
  env.key = EscapeKey.New(env.window, {
    createFrame = factory.CreateFrame,
    getBindingKey = function(action)
      assert(action == "TOGGLEGAMEMENU", "ESC is the game-menu binding")
      return "ESCAPE"
    end,
    inCombat = function()
      return env.combat
    end,
    setOverrideBindingClick = function(owner, priority, key, buttonName)
      if env.combat then
        env.blocked = env.blocked + 1
      end
      assert(priority == true, "the override must beat the game-menu binding")
      env.owner, env.buttonName = owner, buttonName
      table.insert(env.bound, key)
    end,
    clearOverrideBindings = function(owner)
      if env.combat then
        env.blocked = env.blocked + 1
      end
      assert(owner == env.owner, "clear only the overrides this button owns")
      env.bound = {}
    end,
  })
  function env.fire(event)
    env.owner:GetScript("OnEvent")(env.owner, event)
  end
  return env
end

return function()
  -- test_focused_window_takes_the_escape_key
  local env = newEnv()
  env.key.setFocused(true)
  assert(#env.bound == 1 and env.bound[1] == "ESCAPE", "ESC must go to the messenger while it has focus")

  -- test_escape_key_closes_the_window
  env = newEnv()
  env.key.setFocused(true)
  env.owner:GetScript("OnClick")(env.owner, "LeftButton", true)
  assert(not env.window:IsShown(), "ESC must close the focused messenger")

  -- test_losing_focus_gives_the_escape_key_back
  env = newEnv()
  env.key.setFocused(true)
  env.key.setFocused(false)
  assert(#env.bound == 0, "ESC must go back to the game once the messenger loses focus")

  -- test_hidden_window_never_takes_the_escape_key
  env = newEnv()
  env.window:Hide()
  env.key.setFocused(true)
  assert(#env.bound == 0, "a hidden messenger must not eat ESC")

  -- test_window_under_hidden_ui_never_takes_the_escape_key
  -- Alt+Z hides UIParent: the window is still "shown" but not on screen.
  env = newEnv(function(factory)
    local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
    uiParent:Hide()
    return uiParent
  end)
  env.key.setFocused(true)
  assert(#env.bound == 0, "a messenger hidden with the whole UI must not eat ESC")

  -- test_focus_in_combat_leaves_bindings_alone
  -- Binding changes are blocked in combat.
  env = newEnv()
  env.combat = true
  env.key.setFocused(true)
  assert(#env.bound == 0 and env.blocked == 0, "no binding change may happen in combat")

  -- test_combat_start_gives_the_escape_key_back
  -- PLAYER_REGEN_DISABLED fires before the lockdown starts, so ESC can still
  -- be handed back; in combat ESC must stop casts again.
  env = newEnv()
  env.key.setFocused(true)
  env.fire("PLAYER_REGEN_DISABLED")
  assert(#env.bound == 0 and env.blocked == 0, "combat must give ESC back to the game")

  -- test_combat_end_takes_the_escape_key_again
  env = newEnv()
  env.key.setFocused(true)
  env.fire("PLAYER_REGEN_DISABLED")
  env.fire("PLAYER_REGEN_ENABLED")
  assert(#env.bound == 1, "after combat a still-focused messenger must take ESC again")

  -- test_focus_lost_in_combat_stays_released_after_combat
  env = newEnv()
  env.key.setFocused(true)
  env.fire("PLAYER_REGEN_DISABLED")
  env.combat = true
  env.key.setFocused(false)
  env.combat = false
  env.fire("PLAYER_REGEN_ENABLED")
  assert(#env.bound == 0, "a messenger that lost focus in combat must not take ESC after it")
end
