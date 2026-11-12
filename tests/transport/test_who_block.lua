local WhoBlock = require("WhisperMessenger.Transport.WhoBlock")

local function withGlobals(overrides, fn)
  local names = { "InCombatLockdown", "C_ChatInfo", "C_Timer" }
  local saved = {}
  for _, name in ipairs(names) do
    saved[name] = _G[name]
  end
  _G.InCombatLockdown = function()
    return false
  end
  _G.C_ChatInfo = {}
  _G.C_Timer = { NewTimer = function() end }
  for name, value in pairs(overrides) do
    _G[name] = value
  end
  local ok, err = pcall(fn)
  for _, name in ipairs(names) do
    _G[name] = saved[name]
  end
  if not ok then
    error(err, 0)
  end
end

local function test_open_world_is_not_blocked()
  withGlobals({}, function()
    assert(WhoBlock.IsBlocked({}) == false)
  end)
end

local function test_combat_blocks()
  withGlobals({
    InCombatLockdown = function()
      return true
    end,
  }, function()
    assert(WhoBlock.IsBlocked({}) == true)
  end)
end

local function test_chat_lockdown_blocks()
  withGlobals({
    C_ChatInfo = {
      InChatMessagingLockdown = function()
        return true
      end,
    },
  }, function()
    assert(WhoBlock.IsBlocked({}) == true)
  end)
end

local function test_mythic_lockdown_blocks()
  withGlobals({}, function()
    assert(WhoBlock.IsBlocked({
      isMythicLockdown = function()
        return true
      end,
    }) == true)
  end)
end

local function test_missing_new_timer_blocks()
  withGlobals({ C_Timer = {} }, function()
    assert(WhoBlock.IsBlocked({}) == true)
  end)
end

local function test_competitive_content_blocks()
  withGlobals({}, function()
    assert(WhoBlock.IsBlocked({
      isCompetitiveContent = function()
        return true
      end,
    }) == true)
  end)
end

test_open_world_is_not_blocked()
test_combat_blocks()
test_chat_lockdown_blocks()
test_mythic_lockdown_blocks()
test_missing_new_timer_blocks()
test_competitive_content_blocks()
