local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")

local TYPES = RestrictedActions.TYPES
local STATES = RestrictedActions.STATES

local function withStubs(chatInfo, fn)
  local savedChatInfo = _G.C_ChatInfo
  local savedRestricted = _G.C_RestrictedActions
  _G.C_ChatInfo = chatInfo
  _G.C_RestrictedActions = nil
  fn()
  _G.C_ChatInfo = savedChatInfo
  _G.C_RestrictedActions = savedRestricted
end

local function lockdownApi(result)
  return {
    InChatMessagingLockdown = function()
      return result
    end,
  }
end

return function()
  -- test_chat_type_is_5

  do
    assert(TYPES.Chat == 5, "Chat must be 5 per Enum.AddOnRestrictionType")
  end

  -- test_is_chat_locked_true_from_type5_cache_while_api_false

  do
    withStubs(lockdownApi(false), function()
      local ra = RestrictedActions.New()
      ra.updateFromEvent(TYPES.Chat, STATES.Activating)
      assert(ra.isChatLocked() == true, "cached type 5 must lock chat even when the API says false")
    end)
  end

  -- test_is_chat_locked_true_from_api_with_empty_cache

  do
    withStubs(lockdownApi(true), function()
      local ra = RestrictedActions.New()
      assert(ra.isChatLocked() == true, "InChatMessagingLockdown true must lock chat")
    end)
  end

  -- test_is_chat_locked_false_when_api_missing

  do
    withStubs({}, function()
      local ra = RestrictedActions.New()
      assert(ra.isChatLocked() == false, "missing API must read as unlocked")
    end)
  end

  -- test_is_chat_locked_false_when_api_errors

  do
    withStubs({
      InChatMessagingLockdown = function()
        error("x")
      end,
    }, function()
      local ra = RestrictedActions.New()
      assert(ra.isChatLocked() == false, "API error must read as unlocked")
    end)
  end

  -- test_is_chat_locked_false_when_api_returns_secret

  do
    local SECRET = {}
    local savedIsSecret = rawget(_G, "issecretvalue")
    rawset(_G, "issecretvalue", function(v)
      return v == SECRET
    end)
    withStubs(lockdownApi(SECRET), function()
      local ra = RestrictedActions.New()
      assert(ra.isChatLocked() == false, "secret API result must read as unlocked")
    end)
    rawset(_G, "issecretvalue", savedIsSecret)
  end

  -- test_chat_inactive_event_clears_cache

  do
    withStubs(lockdownApi(false), function()
      local ra = RestrictedActions.New()
      ra.updateFromEvent(TYPES.Chat, STATES.Activating)
      ra.updateFromEvent(TYPES.Chat, STATES.Inactive)
      assert(ra.isChatLocked() == false, "Inactive type 5 must clear the cached lock")
    end)
  end
end
