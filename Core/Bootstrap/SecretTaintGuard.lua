local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local unpack = table.unpack or unpack

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")

-- Maximum number of event args WoW whisper events carry (matches WoW's event arg count cap).
local MAX_EVENT_ARGS = 29
-- Maximum items held in the deferred queue before FIFO eviction kicks in.
local MAX_QUEUE_SIZE = 200

-- Channel events: tagged on enqueue so the drain can drop them silently.
-- Replaying 20 minutes of Trade/LFG after a key ends would bury whispers.
local CHANNEL_EVENT_NAMES = {
  CHAT_MSG_CHANNEL = true,
}

local SecretTaintGuard = {}

-- packArgs(...) -> table
-- Captures event varargs with their exact count into a plain table so the
-- drain path can unpack them back later. Unlike the previous sanitizeArgs
-- helper we do NOT replace tainted values with empty strings — Blizzard's
-- secret-string marker only prevents passing a value into certain protected
-- APIs (SendChatMessage, ChatEdit_SetLastTellTarget, the secure template
-- path). Reading the value into a Lua table is safe, and by the time the
-- drain replays these through EventRouter → ConversationStore → UI the
-- lockdown has cleared, so downstream rendering (FontString:SetText in
-- chat bubbles) works — the same path Blizzard's own default chat uses to
-- display the whispers during the lockdown itself. Replacing the values
-- with "" on enqueue meant drained whispers arrived at the UI as empty
-- messages from unnamed senders and never surfaced.
local function packArgs(...)
  local n = select("#", ...)
  local limit = n < MAX_EVENT_ARGS and n or MAX_EVENT_ARGS
  local args = { n = limit }
  for i = 1, limit do
    args[i] = select(i, ...)
  end
  return args
end

-- TryDefer(runtime, eventName, ...) -> boolean
-- Returns true and enqueues a copy when any arg is tainted.
-- Returns false when args are clean (caller should route normally).
function SecretTaintGuard.TryDefer(runtime, eventName, ...)
  if not FlavorCompat.HasAnySecretValues(...) then
    return false
  end

  local packed = packArgs(...)
  runtime.secretDeferredQueue = runtime.secretDeferredQueue or {}
  if #runtime.secretDeferredQueue >= MAX_QUEUE_SIZE then
    table.remove(runtime.secretDeferredQueue, 1)
    if ns.Trace then
      ns.Trace("SecretTaintGuard: queue cap reached, evicted oldest")
    end
  end
  table.insert(runtime.secretDeferredQueue, {
    eventName = eventName,
    args = packed,
    isChannel = CHANNEL_EVENT_NAMES[eventName] == true,
  })
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
  local droppedChannel = 0
  while #q > 0 do
    local item = table.remove(q, 1)
    if item.isChannel then
      droppedChannel = droppedChannel + 1
    else
      EventBridge.RouteLiveEvent(
        runtime,
        refreshWindow,
        item.eventName,
        unpack(item.args, 1, item.args.n or MAX_EVENT_ARGS)
      )
    end
    count = count + 1
  end
  if count > 0 and ns.Trace then
    ns.Trace("SecretTaintGuard: drained " .. count .. " deferred events (" .. droppedChannel .. " channel dropped)")
  end
  return count
end

ns.BootstrapSecretTaintGuard = SecretTaintGuard
return SecretTaintGuard
