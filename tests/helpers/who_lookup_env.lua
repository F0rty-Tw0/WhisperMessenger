-- Fakes for WhoLookup tests: C_FriendList, FriendsFrame, a C_Timer that
-- captures callbacks instead of running them, a hooksecurefunc that post-hooks
-- like the real one, and GetTime plus a runtime sharing one controllable
-- clock. Case() restores every global afterwards.
local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local SeenLevel = require("WhisperMessenger.Model.SeenLevel")

local WhoLookupEnv = {}

local GLOBALS = {
  "C_FriendList",
  "FriendsFrame",
  "C_Timer",
  "hooksecurefunc",
  "InCombatLockdown",
  "C_ChatInfo",
  "_wmSuspended",
  "GetTime",
}

local function installFriendList(env, opts)
  env.api = {
    SendWho = function(filter)
      table.insert(env.sent, filter)
    end,
    SetWhoToUi = function(value)
      table.insert(env.whoToUi, value)
    end,
  }
  if opts.whoToUi ~= nil then
    env.api.GetWhoToUi = function()
      return opts.whoToUi
    end
  end
  rawset(_G, "C_FriendList", env.api)
end

local function installFriendsFrame(env)
  env.friendsRegistered = true
  rawset(_G, "FriendsFrame", {
    RegisterEvent = function(_self, event)
      if event == "WHO_LIST_UPDATE" then
        env.friendsRegistered = true
      end
    end,
    UnregisterEvent = function(_self, event)
      if event == "WHO_LIST_UPDATE" then
        env.friendsRegistered = false
      end
    end,
  })
end

local function installTimers(env)
  rawset(_G, "C_Timer", {
    After = function(seconds, callback)
      table.insert(env.afters, { seconds = seconds, callback = callback })
    end,
    NewTimer = function(seconds, callback)
      local timer = { seconds = seconds, callback = callback, createdAt = env.clock }
      function timer.Cancel(self)
        self.cancelled = true
      end
      table.insert(env.timers, timer)
      return timer
    end,
  })
end

local function installRuntime(env)
  env.conversations = {}
  env.runtime = {
    store = { conversations = env.conversations },
    now = function()
      return env.clock
    end,
    isMythicLockdown = function()
      return env.mythic == true
    end,
    isCompetitiveContent = function()
      return env.competitive == true
    end,
  }
end

function WhoLookupEnv.New(opts)
  opts = opts or {}
  local env = { clock = 1000, sent = {}, whoToUi = {}, afters = {}, timers = {}, hooks = {}, saved = {} }
  for _, key in ipairs(GLOBALS) do
    env.saved[key] = rawget(_G, key)
  end
  installFriendList(env, opts)
  installFriendsFrame(env)
  installTimers(env)
  rawset(_G, "hooksecurefunc", function(target, method, hook)
    table.insert(env.hooks, { target = target, method = method, hook = hook })
    local original = target[method]
    target[method] = function(...)
      original(...)
      hook(...)
    end
  end)
  rawset(_G, "GetTime", function()
    return env.clock
  end)
  rawset(_G, "InCombatLockdown", function()
    return env.inCombat == true
  end)
  rawset(_G, "C_ChatInfo", {
    InChatMessagingLockdown = function()
      return env.chatLockdown == true
    end,
  })
  rawset(_G, "_wmSuspended", nil)
  installRuntime(env)
  DisplayName.Configure({ showPlayerLevels = true })
  SeenLevel._reset()
  WhoLookup._reset()
  WhoLookup.Init(env.runtime)
  return env
end

function WhoLookupEnv.Restore(env)
  for _, key in ipairs(GLOBALS) do
    rawset(_G, key, env.saved[key])
  end
  DisplayName.Configure({ showPlayerLevels = false })
  SeenLevel._reset()
  WhoLookup._reset()
end

function WhoLookupEnv.AddStranger(env, key, displayName, fields)
  local conversation = { channel = "WOW", displayName = displayName }
  for field, value in pairs(fields or {}) do
    conversation[field] = value
  end
  env.conversations[key] = conversation
  return conversation
end

-- Stands in for another addon (or the game) re-wrapping SendWho after Init.
function WhoLookupEnv.ReplaceSendWho(env, fn)
  env.api.SendWho = fn
end

function WhoLookupEnv.RunAfters(env)
  local pending = env.afters
  env.afters = {}
  for _, entry in ipairs(pending) do
    entry.callback()
  end
end

-- Fires every timer that is due by the clock and was not cancelled.
function WhoLookupEnv.FireDueTimers(env)
  local fired = 0
  for _, timer in ipairs(env.timers) do
    if not timer.cancelled and not timer.fired and env.clock >= timer.createdAt + timer.seconds then
      timer.fired = true
      fired = fired + 1
      timer.callback(timer)
    end
  end
  return fired
end

function WhoLookupEnv.Case(label, opts, fn)
  local env = WhoLookupEnv.New(opts)
  local ok, err = pcall(fn, env)
  WhoLookupEnv.Restore(env)
  assert(ok, label .. ": " .. tostring(err))
end

return WhoLookupEnv
