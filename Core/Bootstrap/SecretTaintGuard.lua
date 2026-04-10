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

-- washString(s) -> string
-- Produces a new Lua string with the same content but WITHOUT Blizzard's
-- secret-string marker. Blizzard flags specific string instances as
-- "secret" during chat-secrecy lockdown; ==, .., and even the # length
-- operator are blocked on those values from addon code.
--
-- We avoid every blocked op (length, compare, concat) and try to probe
-- the string byte-by-byte via string.byte() until it returns nil for
-- the past-the-end position. Each byte is a number (untainted), each
-- string.char(...) returns a fresh allocation, and table.concat joins
-- them into a clean Lua string.
--
-- The whole probe runs inside pcall: if Blizzard also blocks string.byte
-- on secret values, we return a non-empty placeholder so the drained
-- replay can still create a stub conversation entry instead of crashing.
local SECRET_PLACEHOLDER = "<lockdown>"

local function washString(s)
  if type(s) ~= "string" then
    return s
  end
  local ok, result = pcall(function()
    local chars = {}
    local i = 1
    while true do
      local b = string.byte(s, i)
      if b == nil then
        break
      end
      chars[i] = string.char(b)
      i = i + 1
    end
    return table.concat(chars)
  end)
  if ok and type(result) == "string" then
    return result
  end
  return SECRET_PLACEHOLDER
end

-- packArgs(...) -> table
-- Captures event varargs with their exact count into a plain table so the
-- drain path can unpack them back later. Any Blizzard secret-string
-- argument is washed into a clean copy via washString(); the drain then
-- routes the clean copies through EventRouter → ConversationStore → UI
-- exactly the same way live (un-tainted) whispers flow.
local function packArgs(...)
  local n = select("#", ...)
  local limit = n < MAX_EVENT_ARGS and n or MAX_EVENT_ARGS
  local args = { n = limit }
  for i = 1, limit do
    local v = select(i, ...)
    if FlavorCompat.IsSecretValue(v) then
      args[i] = washString(v)
    else
      args[i] = v
    end
  end
  return args
end

-- TryDefer(runtime, eventName, ...) -> boolean
-- Returns true and enqueues a copy when any arg is tainted.
-- Returns false when args are clean (caller should route normally).
function SecretTaintGuard.TryDefer(runtime, eventName, ...)
  -- During an active drain, never re-defer. The stored args may still carry
  -- Blizzard's secret-string marker even after the lockdown cleared, so
  -- RouteLiveEvent → HasAnySecretValues would evaluate true again and
  -- re-enqueue every item we just removed, producing an infinite loop.
  if runtime and runtime._wmDraining then
    return false
  end
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
  if type(_G.print) == "function" then
    _G.print(
      "[WM DEBUG] TryDefer: enqueued " .. tostring(eventName) .. " (queue size=" .. #runtime.secretDeferredQueue .. ")"
    )
  end
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
    if type(_G.print) == "function" then
      _G.print("[WM DEBUG] Drain: bailed (InChatMessagingLockdown==true)")
    end
    return 0
  end
  local q = runtime.secretDeferredQueue
  if q == nil or #q == 0 then
    if type(_G.print) == "function" then
      _G.print("[WM DEBUG] Drain: bailed (queue empty)")
    end
    return 0
  end
  if type(_G.print) == "function" then
    _G.print("[WM DEBUG] Drain: starting, queue size=" .. #q)
  end

  -- Require EventBridge lazily to avoid a circular require at module load time.
  local EventBridge = ns.BootstrapEventBridge or require("WhisperMessenger.Core.Bootstrap.EventBridge")

  runtime._wmDraining = true
  local count = 0
  local droppedChannel = 0
  while #q > 0 do
    local item = table.remove(q, 1)
    if item.isChannel then
      droppedChannel = droppedChannel + 1
      if type(_G.print) == "function" then
        _G.print("[WM DEBUG] Drain: dropped channel item " .. tostring(item.eventName))
      end
    else
      if type(_G.print) == "function" then
        _G.print("[WM DEBUG] Drain: routing " .. tostring(item.eventName))
      end
      EventBridge.RouteLiveEvent(
        runtime,
        refreshWindow,
        item.eventName,
        unpack(item.args, 1, item.args.n or MAX_EVENT_ARGS)
      )
    end
    count = count + 1
  end
  runtime._wmDraining = nil
  if type(_G.print) == "function" then
    _G.print("[WM DEBUG] Drain: done, routed=" .. count .. " droppedChannel=" .. droppedChannel)
  end
  if count > 0 and ns.Trace then
    ns.Trace("SecretTaintGuard: drained " .. count .. " deferred events (" .. droppedChannel .. " channel dropped)")
  end
  return count
end

-- RescanChatForPlaceholders(runtime, refreshWindow) -> number
-- After drain creates stub entries with <lockdown> text/sender, this
-- function scans the default chat frame's message buffer for the same
-- lineIDs and replaces placeholders with real content. Blizzard's
-- secure code formatted those whispers into readable strings when it
-- added them to the chat frame; GetMessageInfo returns that formatted
-- text which we can parse for sender name and body.
--
-- Call this 2-3 seconds after drain to give Blizzard's chat frame time
-- to process the messages. If the formatted text is still tainted, the
-- pcall catches the error and the placeholder stays.
function SecretTaintGuard.RescanChatForPlaceholders(runtime, refreshWindow)
  if runtime == nil or runtime.store == nil then
    return 0
  end

  local frame = _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1
  if not frame or type(frame.GetNumMessages) ~= "function" or type(frame.GetMessageInfo) ~= "function" then
    return 0
  end

  -- Collect lineIDs from <lockdown> messages across all conversations
  local targets = {}
  local targetCount = 0
  for convKey, conversation in pairs(runtime.store.conversations) do
    for i, msg in ipairs(conversation.messages or {}) do
      if
        type(msg.lineID) == "number"
        and (msg.text == SECRET_PLACEHOLDER or (msg.playerName and msg.playerName == SECRET_PLACEHOLDER))
      then
        targets[msg.lineID] = { convKey = convKey, conv = conversation, idx = i, msg = msg }
        targetCount = targetCount + 1
      end
    end
  end

  if targetCount == 0 then
    return 0
  end

  -- Walk the chat frame backwards (newest first) looking for matching lineIDs
  local numMessages = frame:GetNumMessages()
  local replaced = 0
  for i = numMessages, 1, -1 do
    if targetCount <= 0 then
      break
    end
    local ok, text, _, _, _, _, _, lineID = pcall(frame.GetMessageInfo, frame, i)
    if ok and type(lineID) == "number" and targets[lineID] and type(text) == "string" then
      -- Try to parse sender + body from Blizzard's formatted whisper text.
      -- Typical format (locale-independent structure):
      --   |Hplayer:Name-Realm:...|h[Name-Realm]|h whispers: body text|r
      --   To |Hplayer:Name-Realm:...|h[Name-Realm]|h: body text|r
      local parseOk, sender, body = pcall(function()
        local s = string.match(text, "|h%[([^%]]+)%]|h")
        local b = string.match(text, "|h%[.-%]|h.-:%s*(.*)")
        if b then
          b = string.gsub(b, "|r$", "")
        end
        return s, b
      end)
      if parseOk and type(sender) == "string" and sender ~= "" then
        local entry = targets[lineID]
        if type(body) == "string" and body ~= "" then
          entry.msg.text = body
        end
        entry.msg.playerName = sender
        if entry.conv.displayName == SECRET_PLACEHOLDER then
          entry.conv.displayName = sender
        end
        replaced = replaced + 1
        targets[lineID] = nil
        targetCount = targetCount - 1
      end
    end
  end

  if replaced > 0 then
    if type(_G.print) == "function" then
      _G.print("[WM DEBUG] RescanChat: replaced " .. replaced .. " placeholder(s) with real content")
    end
    if type(refreshWindow) == "function" then
      refreshWindow()
    end
  end

  return replaced
end

ns.BootstrapSecretTaintGuard = SecretTaintGuard
return SecretTaintGuard
