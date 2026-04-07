-- Tests for Core/FlavorCompat.lua chat-secrecy taint API wrappers.
-- Each do-block is an isolated scenario; package.loaded is cleared between
-- re-require calls so the module re-runs its upvalue probing from scratch.

local MODULE_KEY = "WhisperMessenger.Core.FlavorCompat"

local function reload()
  package.loaded[MODULE_KEY] = nil
  return require(MODULE_KEY)
end

return function()
  -- -----------------------------------------------------------------------
  -- test_is_secret_value_returns_false_when_global_missing
  -- -----------------------------------------------------------------------
  do
    local saved = _G.issecretvalue
    _G.issecretvalue = nil

    local FC = reload()
    local result = FC.IsSecretValue("anything")
    assert(result == false, "IsSecretValue should return false when _G.issecretvalue is nil, got: " .. tostring(result))

    _G.issecretvalue = saved
  end

  -- -----------------------------------------------------------------------
  -- test_is_secret_value_delegates_to_global_when_present
  -- -----------------------------------------------------------------------
  do
    local saved = _G.issecretvalue
    _G.issecretvalue = function(v)
      return v == "tainted"
    end

    local FC = reload()
    assert(FC.IsSecretValue("tainted") == true, "IsSecretValue should return true for tainted value")
    assert(FC.IsSecretValue("clean") == false, "IsSecretValue should return false for clean value")

    _G.issecretvalue = saved
  end

  -- -----------------------------------------------------------------------
  -- test_has_any_secret_values_returns_false_when_global_missing
  -- -----------------------------------------------------------------------
  do
    local saved = _G.hasanysecretvalues
    _G.hasanysecretvalues = nil

    local FC = reload()
    local result = FC.HasAnySecretValues("a", "b", "c")
    assert(
      result == false,
      "HasAnySecretValues should return false when _G.hasanysecretvalues is nil, got: " .. tostring(result)
    )

    _G.hasanysecretvalues = saved
  end

  -- -----------------------------------------------------------------------
  -- test_has_any_secret_values_delegates_with_varargs
  -- -----------------------------------------------------------------------
  do
    local saved = _G.hasanysecretvalues
    local capturedArgs = {}
    _G.hasanysecretvalues = function(...)
      capturedArgs = { ... }
      -- return true only if "tainted" is among the args
      for _, v in ipairs(capturedArgs) do
        if v == "tainted" then
          return true
        end
      end
      return false
    end

    local FC = reload()
    assert(FC.HasAnySecretValues("a", "b", "c") == false, "HasAnySecretValues should return false for clean args")
    assert(#capturedArgs == 3, "HasAnySecretValues should forward all 3 args, got: " .. #capturedArgs)
    assert(capturedArgs[1] == "a", "first arg should be 'a'")
    assert(capturedArgs[2] == "b", "second arg should be 'b'")
    assert(capturedArgs[3] == "c", "third arg should be 'c'")

    assert(
      FC.HasAnySecretValues("x", "tainted", "y") == true,
      "HasAnySecretValues should return true when tainted present"
    )

    _G.hasanysecretvalues = saved
  end

  -- -----------------------------------------------------------------------
  -- test_in_chat_messaging_lockdown_returns_false_when_C_ChatInfo_nil
  -- -----------------------------------------------------------------------
  do
    local saved = _G.C_ChatInfo
    _G.C_ChatInfo = nil

    local FC = reload()
    local result = FC.InChatMessagingLockdown()
    assert(
      result == false,
      "InChatMessagingLockdown should return false when _G.C_ChatInfo is nil, got: " .. tostring(result)
    )

    _G.C_ChatInfo = saved
  end

  -- -----------------------------------------------------------------------
  -- test_in_chat_messaging_lockdown_returns_false_when_method_missing
  -- -----------------------------------------------------------------------
  do
    local saved = _G.C_ChatInfo
    _G.C_ChatInfo = {} -- table exists but no InChatMessagingLockdown method

    local FC = reload()
    local result = FC.InChatMessagingLockdown()
    assert(
      result == false,
      "InChatMessagingLockdown should return false when method is absent, got: " .. tostring(result)
    )

    _G.C_ChatInfo = saved
  end

  -- -----------------------------------------------------------------------
  -- test_in_chat_messaging_lockdown_delegates_when_present
  -- -----------------------------------------------------------------------
  do
    local saved = _G.C_ChatInfo
    _G.C_ChatInfo = {
      InChatMessagingLockdown = function()
        return true
      end,
    }

    local FC = reload()
    local result = FC.InChatMessagingLockdown()
    assert(
      result == true,
      "InChatMessagingLockdown should return true when method returns true, got: " .. tostring(result)
    )

    _G.C_ChatInfo = saved
  end
end
