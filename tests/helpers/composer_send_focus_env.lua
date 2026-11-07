local FakeUI = require("tests.helpers.fake_ui")
local ComposerSendFocus = require("WhisperMessenger.UI.Composer.ComposerSendFocus")

local ComposerSendFocusEnv = {}

-- Builds a ComposerSendFocus with recorded binding calls. env.on, env.enabled
-- and env.combat drive its state; env.bound lists the keys bound now, and
-- env.blocked counts binding calls made in combat, which the game refuses.
-- The pane sits under the window as in the real one: window > content area >
-- content pane > pane, with the window under UIParent. env.window.mouseOver is
-- the cursor; no other frame in the chain reports it.
function ComposerSendFocusEnv.NewEnv(overrides)
  local factory = FakeUI.NewFactory()
  local env = { on = true, enabled = true, combat = false, keys = { "ENTER" }, bound = {}, binds = 0, blocked = 0 }
  for key, value in pairs(overrides or {}) do
    env[key] = value
  end
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:Show()
  env.window = factory.CreateFrame("Frame", nil, _G.UIParent)
  env.window:Show()
  local contentArea = factory.CreateFrame("Frame", nil, env.window)
  contentArea:Show()
  local contentPane = factory.CreateFrame("Frame", nil, contentArea)
  contentPane:Show()
  env.pane = factory.CreateFrame("Frame", nil, contentPane)
  env.input = factory.CreateFrame("EditBox", nil, env.pane)
  env.focus = ComposerSendFocus.Create(env.pane, env.input, {
    isOn = function()
      return env.on
    end,
    isEnabled = function()
      return env.enabled
    end,
  }, {
    createFrame = function(...)
      env.button = factory.CreateFrame(...)
      function env.button:RegisterForClicks(...)
        self.clickTypes = { ... }
      end
      return env.button
    end,
    getBindingKey = function(action)
      assert(action == "OPENCHAT", "the override follows the open-chat binding")
      return table.unpack(env.keys)
    end,
    inCombat = function()
      return env.combat
    end,
    setOverrideBindingClick = function(owner, priority, key, buttonName)
      if env.combat then
        env.blocked = env.blocked + 1
      end
      assert(priority == true, "the override must beat the game's chat binding")
      assert(owner == env.button, "the override belongs to the module's button")
      env.buttonName = buttonName
      env.binds = env.binds + 1
      table.insert(env.bound, key)
    end,
    clearOverrideBindings = function(owner)
      if env.combat then
        env.blocked = env.blocked + 1
      end
      assert(owner == env.button, "clear only the overrides this button owns")
      env.bound = {}
    end,
  })
  function env.fire(event)
    env.button:GetScript("OnEvent")(env.button, event)
  end
  function env.startCombat()
    env.fire("PLAYER_REGEN_DISABLED")
    env.combat = true
  end
  function env.endCombat()
    env.combat = false
    env.fire("PLAYER_REGEN_ENABLED")
  end
  env.pane:Show()
  return env
end

return ComposerSendFocusEnv
