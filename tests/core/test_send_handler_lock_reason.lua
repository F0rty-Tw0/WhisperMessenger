local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")

local function rt(mythic, competitive)
  return {
    isMythicLockdown = function()
      return mythic
    end,
    isCompetitiveContent = function()
      return competitive
    end,
  }
end

return function()
  local function test_mythic_lockdown_wins_over_competitive()
    assert(SendHandler.LockReason(rt(true, true)) == "Mythic Lockdown", "mythic wins")
  end

  local function test_competitive_content_is_the_reason_without_mythic()
    assert(SendHandler.LockReason(rt(false, true)) == "Competitive Content", "competitive (chat lock included)")
  end

  local function test_no_lock_has_no_reason()
    assert(SendHandler.LockReason(rt(false, false)) == nil, "no lock")
  end

  local function test_runtime_without_checks_is_unlocked()
    assert(SendHandler.LockReason({}) == nil, "a runtime without the checks is unlocked")
  end

  test_mythic_lockdown_wins_over_competitive()
  test_competitive_content_is_the_reason_without_mythic()
  test_no_lock_has_no_reason()
  test_runtime_without_checks_is_unlocked()
end
