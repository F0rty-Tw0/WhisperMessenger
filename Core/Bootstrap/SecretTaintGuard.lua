local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")

-- Maximum number of event args WoW whisper events carry (matches WoW's event arg count cap).
local MAX_EVENT_ARGS = 29

local SecretTaintGuard = {}

-- sanitizeArgs(...) -> table
-- Walks event varargs 1..MAX_EVENT_ARGS and replaces any secret-tainted value
-- with "" (empty string). Returns a plain integer-keyed table so the caller
-- can table.unpack it back into varargs. This mirrors WIM's approach: never
-- pass tainted strings into addon code, replace them with empty strings.
local function sanitizeArgs(...)
  local args = {}
  local n = select("#", ...)
  local limit = n < MAX_EVENT_ARGS and n or MAX_EVENT_ARGS
  for i = 1, limit do
    local v = select(i, ...)
    if FlavorCompat.IsSecretValue(v) then
      args[i] = ""
    else
      args[i] = v
    end
  end
  -- Preserve the arg count so table.unpack(args, 1, MAX_EVENT_ARGS) is safe.
  return args
end

-- TryDefer(runtime, eventName, ...) -> boolean
-- Returns true and enqueues a sanitized copy when any arg is tainted.
-- Returns false when args are clean (caller should route normally).
function SecretTaintGuard.TryDefer(runtime, eventName, ...)
  if not FlavorCompat.HasAnySecretValues(...) then
    return false
  end

  local sanitized = sanitizeArgs(...)
  runtime.secretDeferredQueue = runtime.secretDeferredQueue or {}
  table.insert(runtime.secretDeferredQueue, { eventName = eventName, args = sanitized })
  return true
end

-- DrainSecretDeferredQueue(runtime, refreshWindow) -> number
-- Re-routes all queued secret-deferred events once the lockdown is cleared.
-- Returns the number of items processed (0 if still locked or queue empty).
function SecretTaintGuard.DrainSecretDeferredQueue(runtime, refreshWindow)
  if runtime == nil then
    return 0
  end
  if FlavorCompat.InChatMessagingLockdown() then
    return 0
  end
  local q = runtime.secretDeferredQueue
  if q == nil or #q == 0 then
    return 0
  end

  -- Require EventBridge lazily to avoid a circular require at module load time.
  local EventBridge = ns.BootstrapEventBridge or require("WhisperMessenger.Core.Bootstrap.EventBridge")

  local count = 0
  while #q > 0 do
    local item = table.remove(q, 1)
    EventBridge.RouteLiveEvent(runtime, refreshWindow, item.eventName, table.unpack(item.args, 1, MAX_EVENT_ARGS))
    count = count + 1
  end
  return count
end

ns.BootstrapSecretTaintGuard = SecretTaintGuard
return SecretTaintGuard
