local Env = require("tests.helpers.composer_send_focus_env")

local newEnv = Env.NewEnv

local SECURE_TEMPLATE = "SecureActionButtonTemplate"

return function()
  local savedUIParent = _G.UIParent
  local savedXMLUtil = _G.C_XMLUtil
  local savedGetCVarBool = _G.GetCVarBool

  -- test_button_is_built_from_the_secure_template
  do
    local env = newEnv()
    assert(env.button.template == SECURE_TEMPLATE, "the game ignores a key bound to a plain button in combat")
  end

  -- test_button_sits_under_ui_parent_not_the_window
  do
    local env = newEnv()
    assert(env.button:GetParent() == _G.UIParent, "a secure child would make the window protected in combat")
  end

  -- test_flavor_without_the_template_gets_a_plain_button
  do
    _G.C_XMLUtil = {
      GetTemplateInfo = function()
        return nil
      end,
    }
    local env = newEnv()
    _G.C_XMLUtil = savedXMLUtil
    assert(env.button ~= nil and env.button.template == nil, "a missing template must fall back to a plain button")
    env.pressKey()
    assert(env.focusCount == 1, "the plain button still focuses the composer")
  end

  -- test_key_press_focuses_once_with_either_key_down_setting
  for _, keyDown in ipairs({ true, false }) do
    _G.GetCVarBool = function(name)
      return name == "ActionButtonUseKeyDown" and keyDown
    end
    local env = newEnv()
    env.pressKey()
    _G.GetCVarBool = savedGetCVarBool
    assert(env.focusCount == 1, "one press must focus the composer exactly once (key down " .. tostring(keyDown) .. ")")
  end

  -- test_focus_hooks_the_secure_click_instead_of_replacing_it
  do
    local env = newEnv()
    env.pressKey()
    assert(env.button.secureClicks == 1, "replacing the template's click handler would make the button insecure")
    assert(env.focusCount == 1, "the hook still focuses the composer")
  end

  -- test_window_built_in_combat_makes_its_button_after_the_fight
  do
    local env = newEnv({ combat = true })
    assert(env.button == nil, "a secure button can't be set up in combat")
    env.endCombat()
    assert(env.button ~= nil and env.buttonsCreatedInCombat == 0, "the button is made once combat ends")
    assert(#env.bound == 1, "and takes the key then")
  end

  _G.UIParent = savedUIParent
end
