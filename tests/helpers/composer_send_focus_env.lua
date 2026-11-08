local FakeUI = require("tests.helpers.fake_ui")
local ComposerSendFocus = require("WhisperMessenger.UI.Composer.ComposerSendFocus")

local ComposerSendFocusEnv = {}

local BUTTON_NAME = "WhisperMessengerComposerEnterButton"
local CLICK_PHASES = { { "AnyDown", true }, { "AnyUp", false } }

local function registeredFor(button, clickType)
  for _, registered in ipairs(button.clickTypes or {}) do
    if registered == clickType then
      return true
    end
  end
  return false
end

-- Builds a ComposerSendFocus with recorded binding calls. env.on, env.enabled
-- and env.combat drive its state; env.bound lists the keys bound now, and
-- env.blocked counts binding calls made in combat, which the game refuses.
-- The pane sits under the window as in the real one: window > content area >
-- content pane > pane, with the window under UIParent. env.window.mouseOver is
-- the cursor; no other frame in the chain reports it. env.factory builds more
-- frames for a test. env.button is the key's button once one exists,
-- env.events the frame that takes the game's events, and env.focusCount
-- counts the times the key put the cursor in the composer.
function ComposerSendFocusEnv.NewEnv(overrides)
  local factory = FakeUI.NewFactory()
  local env = {
    factory = factory,
    on = true,
    enabled = true,
    combat = false,
    keys = { "ENTER" },
    bound = {},
    binds = 0,
    blocked = 0,
    focusCount = 0,
    buttonsCreatedInCombat = 0,
  }
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
  env.input:HookScript("OnEditFocusGained", function()
    env.focusCount = env.focusCount + 1
  end)
  env.focus = ComposerSendFocus.Create(env.pane, env.input, {
    isOn = function()
      return env.on
    end,
    isEnabled = function()
      return env.enabled
    end,
  }, {
    createFrame = function(frameType, name, parent, template)
      local frame = factory.CreateFrame(frameType, name, parent, template)
      function frame:RegisterForClicks(...)
        self.clickTypes = { ... }
      end
      if name == BUTTON_NAME then
        env.button = frame
        if env.combat then
          env.buttonsCreatedInCombat = env.buttonsCreatedInCombat + 1
        end
      else
        env.events = frame
      end
      return frame
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
    env.events:GetScript("OnEvent")(env.events, event)
  end
  function env.startCombat()
    env.fire("PLAYER_REGEN_DISABLED")
    env.combat = true
  end
  function env.endCombat()
    env.combat = false
    env.fire("PLAYER_REGEN_ENABLED")
  end
  -- One click on the button: its own OnClick, then every hook, as the game runs them.
  function env.click(down)
    local script = env.button:GetScript("OnClick")
    if script then
      script(env.button, "LeftButton", down)
    end
    for _, hook in ipairs((env.button._hookScripts or {}).OnClick or {}) do
      hook(env.button, "LeftButton", down)
    end
  end
  -- One press of the bound key: the binding clicks the button on the way down
  -- and again on the way up, each only if the button registered for it.
  function env.pressKey()
    for _, phase in ipairs(CLICK_PHASES) do
      if registeredFor(env.button, phase[1]) then
        env.click(phase[2])
      end
    end
  end
  env.pane:Show()
  return env
end

return ComposerSendFocusEnv
