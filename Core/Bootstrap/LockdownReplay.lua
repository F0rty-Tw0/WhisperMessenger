local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local EventBridge = ns.BootstrapEventBridge or require("WhisperMessenger.Core.Bootstrap.EventBridge")
local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
local AlertPolicy = ns.AlertPolicy or require("WhisperMessenger.Model.AlertPolicy")
local ChatPrint = ns.ChatPrint or require("WhisperMessenger.Util.ChatPrint")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
-- stylua: ignore
local IncomingAlerts = ns.BootstrapEventBridgeIncomingAlerts or require("WhisperMessenger.Core.Bootstrap.EventBridge.IncomingAlerts")

local ipairs = ipairs
local pcall = pcall
local type = type

-- Files the whispers the lockdown catcher held once chat is readable again:
-- each held line is read back by line ID and routed as a replayed event at
-- the time it arrived. Lines still unreadable are retried on the next tick.
local LockdownReplay = {}

LockdownReplay.MAX_TRIES = 40
LockdownReplay.TICK_SECONDS = 1

local ONE_FILED_KEY = "1 whisper arrived during the fight."
local MANY_FILED_KEY = "%d whispers arrived during the fight."
local ONE_LOST_KEY = "1 whisper from the fight couldn't be recovered — check your chat."
local MANY_LOST_KEY = "%d whispers from the fight couldn't be recovered — check your chat."

local BNET_EVENTS = {
  CHAT_MSG_BN_WHISPER = true,
  CHAT_MSG_BN_WHISPER_INFORM = true,
}

local function isSecret(value)
  local issecretvalue = _G.issecretvalue
  return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local function isReadable(value)
  return not isSecret(value) and type(value) == "string" and value ~= ""
end

local function readField(reader, lineID)
  if type(reader) ~= "function" then
    return nil
  end
  local ok, value = pcall(reader, lineID)
  if ok then
    return value
  end
  return nil
end

-- Returns text, name, guid once the line reads back cleanly, or nil.
-- Battle.net lines are filed by account, so their GUID is not read.
local function readChatLine(chatInfo, lineID, isBNet)
  local text = readField(chatInfo.GetChatLineText, lineID)
  local name = readField(chatInfo.GetChatLineSenderName, lineID)
  local guid = nil
  if not isBNet then
    guid = readField(chatInfo.GetChatLineSenderGUID, lineID)
  end
  if not isReadable(text) or not isReadable(name) or isSecret(guid) then
    return nil
  end
  return text, name, guid
end

local function resetBatch(state)
  state.filed = 0
  state.lost = 0
  state.anyAlert = false
  state.latestIncoming = nil
end

local function ensureState(runtime)
  local state = runtime.lockdownReplay
  if state == nil then
    state = { drained = {}, ticker = nil, lastSummary = nil }
    resetBatch(state)
    runtime.lockdownReplay = state
  end
  return state
end

local function stopTicker(state)
  if state and state.ticker then
    state.ticker:Cancel()
    state.ticker = nil
  end
end

local function accountSettings(runtime)
  return runtime.accountState and runtime.accountState.settings
end

local function printCount(count, oneKey, manyKey)
  if count == 1 then
    ChatPrint.Print(Localization.Text(oneKey))
  elseif count > 1 then
    ChatPrint.Print(string.format(Localization.Text(manyKey), count))
  end
end

-- One alert, one reply-key move and one refresh for the whole batch. A live
-- whisper newer than the latest held one keeps the reply key.
local function finishBatch(runtime, state)
  stopTicker(state)
  state.lastSummary = { filed = state.filed, lost = state.lost }
  if state.anyAlert then
    IncomingAlerts.Notify(accountSettings(runtime))
  end
  local latest = state.latestIncoming
  local liveAt = runtime.lastIncomingWhisperAt
  if latest and (liveAt == nil or liveAt <= latest.receivedAt) then
    runtime.lastIncomingWhisperKey = latest.conversationKey
  end
  printCount(state.filed, ONE_FILED_KEY, MANY_FILED_KEY)
  printCount(state.lost, ONE_LOST_KEY, MANY_LOST_KEY)
  if type(runtime.refreshWindow) == "function" then
    runtime.refreshWindow()
  end
  resetBatch(state)
end

local function loseLine(state, line)
  if line.incoming then
    state.lost = state.lost + 1
  end
end

local function trackIncoming(runtime, state, line, result)
  if AlertPolicy.ShouldAlert(result, accountSettings(runtime)) then
    state.anyAlert = true
  end
  local latest = state.latestIncoming
  if result.conversationKey and (latest == nil or line.receivedAt >= latest.receivedAt) then
    state.latestIncoming = { receivedAt = line.receivedAt, conversationKey = result.conversationKey }
  end
end

local function routeLine(runtime, state, line, text, name, guid, bnetAccountID)
  -- stylua: ignore
  local result, resultMeta = EventBridge.RouteReplayedEvent(
    runtime, runtime.refreshWindow, line.event, line.receivedAt,
    text, name, nil, nil, nil, nil, nil, nil, nil, nil, line.lineID, guid, bnetAccountID
  )
  if line.incoming and result ~= nil and not (resultMeta and resultMeta.reactionControl == true) then
    state.filed = state.filed + 1
    trackIncoming(runtime, state, line, result)
  end
end

-- Returns true once the line is done with (filed or lost), false to retry it.
local function processLine(runtime, state, line)
  local chatInfo = _G.C_ChatInfo or {}
  if readField(chatInfo.IsValidChatLine, line.lineID) == false then
    loseLine(state, line)
    return true
  end

  local isBNet = BNET_EVENTS[line.event] == true
  local text, name, guid = readChatLine(chatInfo, line.lineID, isBNet)
  if text == nil then
    line.tries = (line.tries or 0) + 1
    if line.tries >= LockdownReplay.MAX_TRIES then
      loseLine(state, line)
      return true
    end
    return false
  end

  local bnetAccountID = nil
  if isBNet then
    bnetAccountID = BNetResolver.ResolveAccountIDByAccountName(runtime.bnetApi, name)
    if bnetAccountID == nil then
      loseLine(state, line)
      return true
    end
  end

  routeLine(runtime, state, line, text, name, guid, bnetAccountID)
  return true
end

function LockdownReplay.IsReady(runtime)
  if runtime == nil or type(runtime.isChatLocked) ~= "function" then
    return false
  end
  return not runtime.isChatLocked() and _G._wmSuspended ~= true
end

function LockdownReplay.IsPending(runtime)
  local catcher = runtime and runtime.lockdownCatcher
  if catcher == nil then
    return false
  end
  local state = runtime.lockdownReplay
  return not catcher.isEmpty() or (state ~= nil and #state.drained > 0)
end

function LockdownReplay.Kick(runtime)
  if not LockdownReplay.IsPending(runtime) or not LockdownReplay.IsReady(runtime) then
    return
  end
  local state = ensureState(runtime)
  local timer = _G.C_Timer
  if state.ticker or type(timer) ~= "table" or type(timer.NewTicker) ~= "function" then
    return
  end
  state.ticker = timer.NewTicker(LockdownReplay.TICK_SECONDS, function()
    LockdownReplay.Tick(runtime)
  end)
end

function LockdownReplay.Tick(runtime)
  local catcher = runtime and runtime.lockdownCatcher
  if catcher == nil then
    return
  end
  local state = ensureState(runtime)
  if not LockdownReplay.IsReady(runtime) then
    stopTicker(state)
    return
  end

  local lines, overCapLost = catcher.drain()
  for _, line in ipairs(lines) do
    state.drained[#state.drained + 1] = line
  end
  state.lost = state.lost + (overCapLost or 0)

  -- Lines leave the pending list before they are routed, so an error can
  -- never file one twice; the line that errored is lost.
  local pending = state.drained
  state.drained = {}
  for _, line in ipairs(pending) do
    local ok, done = pcall(processLine, runtime, state, line)
    if not ok then
      loseLine(state, line)
    elseif not done then
      state.drained[#state.drained + 1] = line
    end
  end

  if not LockdownReplay.IsPending(runtime) then
    finishBatch(runtime, state)
  end
end

ns.BootstrapLockdownReplay = LockdownReplay

return LockdownReplay
