local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AddonIntegrations = ns.AddonIntegrations or require("WhisperMessenger.Model.AddonIntegrations")

-- Connect(addonName) -> handle | nil: how an addon names itself, so the player
-- can allow or refuse it in Settings > Addons using Whisper Messenger.
-- addonName is the addon's folder name: a string with a visible character, at
-- most 64 bytes, no "|". Anything else returns nil and records nothing.
-- The same name always returns the same handle table, and the handle's functions
-- are the same on every call. The handle has `version` (still 1) and every
-- shared-table function except Connect, so `WhisperMessengerAPI.X(...)` becomes
-- `handle.X(...)`. A handle call the player has refused (or any call when
-- "Allow addon integration" was off at load) does nothing and returns false
-- (0 from GetUnreadCount). Connect itself is never refused: an addon can connect
-- first and find out later. Calling the shared table directly still works, but
-- counts as "Other addons".
-- Detect support with `type(api.Connect) == "function"`: older Whisper
-- Messenger versions lack it, and `version` does not change.
local Connect = {}

local SHARED = AddonIntegrations.SHARED
local HANDLE_VERSION = 1
local MAX_NAME_BYTES = 64

function Connect.Refuse()
  return false
end

-- GetUnreadCount promises an integer, so its refusal is 0, not false.
function Connect.RefuseCount(_name)
  return 0
end

local function refusalFor(key)
  return key == "GetUnreadCount" and Connect.RefuseCount or Connect.Refuse
end

local function isValidName(name)
  return type(name) == "string" and name:find("%S") ~= nil and #name <= MAX_NAME_BYTES and not name:find("|", 1, true)
end

-- The public API never throws: a registry that raises refuses the call.
local function isAllowed(registry, caller)
  local ok, allowed = pcall(registry.isAllowed, caller)
  return ok and allowed == true
end

-- runtime.apiCaller names who is calling while raw runs, and is always put
-- back: a stuck caller would mis-own every later WoW-internal claim.
local function wrap(raw, key, caller, runtime, registry)
  local refusal = refusalFor(key)
  return function(...)
    if not isAllowed(registry, caller) then
      return refusal(...)
    end
    local previous = runtime.apiCaller
    runtime.apiCaller = caller
    local ok, result = pcall(raw, ...)
    runtime.apiCaller = previous
    if not ok then
      return refusal(...)
    end
    return result
  end
end

local function buildHandle(name, raws, runtime, registry)
  local handle = { version = HANDLE_VERSION }
  for key, raw in pairs(raws) do
    if runtime.integrationAllowedAtLoad == false then
      handle[key] = refusalFor(key)
    else
      handle[key] = wrap(raw, key, name, runtime, registry)
    end
  end
  return handle
end

-- Runs last among the installs: it wraps every function already on `api`.
function Connect.Install(api, runtime)
  local registry = runtime.addonIntegrations
  local raws = {}
  for key, value in pairs(api) do
    if type(value) == "function" then
      raws[key] = value
    end
  end

  -- The shared table is "Other addons": counted on every call, even refused ones.
  for key, raw in pairs(raws) do
    local sharedCall = wrap(raw, key, SHARED, runtime, registry)
    api[key] = function(...)
      pcall(registry.touch, SHARED)
      return sharedCall(...)
    end
  end

  local handles = {}
  api.Connect = function(name)
    local ok, handle = pcall(function()
      if not isValidName(name) then
        return nil
      end
      registry.touch(name)
      handles[name] = handles[name] or buildHandle(name, raws, runtime, registry)
      return handles[name]
    end)
    return ok and handle or nil
  end
end

ns.PublicApiConnect = Connect
return Connect
