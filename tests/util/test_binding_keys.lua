local BindingKeys = require("WhisperMessenger.Util.BindingKeys")

return function()
  -- test_returns_every_key_in_order
  do
    local keys = BindingKeys.ForAction(function()
      return "ENTER", "NUMPADENTER"
    end, "OPENCHAT")
    assert(#keys == 2 and keys[1] == "ENTER" and keys[2] == "NUMPADENTER", "every bound key, in order")
  end

  -- test_passes_the_action_to_the_getter
  do
    local seen = nil
    BindingKeys.ForAction(function(action)
      seen = action
    end, "OPENCHAT")
    assert(seen == "OPENCHAT", "the getter must receive the action")
  end

  -- test_skips_empty_and_non_string_slots
  do
    local keys = BindingKeys.ForAction(function()
      return "", "ENTER", 5
    end, "OPENCHAT")
    assert(#keys == 1 and keys[1] == "ENTER", "only non-empty strings are keys")
  end

  -- test_no_getter_returns_empty
  do
    local keys = BindingKeys.ForAction(nil, "OPENCHAT")
    assert(#keys == 0, "no getter means no keys")
  end

  -- test_unbound_action_returns_empty
  do
    local keys = BindingKeys.ForAction(function() end, "OPENCHAT")
    assert(#keys == 0, "an unbound action has no keys")
  end
end
