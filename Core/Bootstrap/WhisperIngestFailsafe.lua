local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatPrint = ns.ChatPrint or require("WhisperMessenger.Util.ChatPrint")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

local select = select
local type = type
local unpack = _G.unpack or table.unpack
local xpcall = xpcall

-- The whisper chat filters always hide these lines from the default chat, so
-- an error in our ingest would lose the whisper. The failsafe reports the
-- error, shows the line in chat, and after MAX_ERRORS stops hiding whispers
-- for the rest of the session.
local WhisperIngestFailsafe = {}

WhisperIngestFailsafe.MAX_ERRORS = 3

local DIRECTION_BY_EVENT = {
  CHAT_MSG_WHISPER = "in",
  CHAT_MSG_BN_WHISPER = "in",
  CHAT_MSG_WHISPER_INFORM = "out",
  CHAT_MSG_BN_WHISPER_INFORM = "out",
}

local INCOMING_KEY = "Couldn't store a whisper from %s: %s"
local OUTGOING_KEY = "Couldn't store a whisper to %s: %s"
local STOPPED_KEY = "WhisperMessenger hit repeated errors and stopped hiding whispers from chat until you /reload."

-- Runs at the error point, so the error handler (BugSack, the Lua error
-- popup) still sees the stack that failed.
local function reportError(err)
  local getErrorHandler = _G.geterrorhandler
  local handler = type(getErrorHandler) == "function" and getErrorHandler() or nil
  if type(handler) == "function" then
    handler(err)
  end
  return err
end

local function isPrintable(value)
  return not SecretValue.Is(value) and type(value) == "string"
end

local function echoWhisper(direction, text, name)
  if not isPrintable(text) or not isPrintable(name) then
    return
  end
  local key = direction == "out" and OUTGOING_KEY or INCOMING_KEY
  ChatPrint.Print(string.format(Localization.Text(key), name, text))
end

local function hidesWhispers(runtime)
  local settings = type(runtime) == "table" and runtime.accountState and runtime.accountState.settings
  return type(settings) == "table" and settings.hideFromDefaultChat == true
end

local function stopHidingWhispers(Bootstrap, runtime)
  Bootstrap._whisperFiltersDisabled = true
  if type(Bootstrap.syncChatFilters) == "function" then
    Bootstrap.syncChatFilters()
  end
  if hidesWhispers(runtime) then
    ChatPrint.Print(Localization.Text(STOPPED_KEY))
  end
end

local function onIngestError(Bootstrap, runtime, direction, text, name)
  if Bootstrap._filtersRegistered then
    echoWhisper(direction, text, name)
  end
  local errorCount = (Bootstrap._whisperIngestErrors or 0) + 1
  Bootstrap._whisperIngestErrors = errorCount
  if errorCount == WhisperIngestFailsafe.MAX_ERRORS then
    stopHidingWhispers(Bootstrap, runtime)
  end
end

-- Same call as EventBridge.RouteLiveEvent; whisper events are guarded.
function WhisperIngestFailsafe.RouteLiveEvent(Bootstrap, EventBridge, runtime, refreshWindow, eventName, ...)
  local direction = DIRECTION_BY_EVENT[eventName]
  if direction == nil then
    return EventBridge.RouteLiveEvent(runtime, refreshWindow, eventName, ...)
  end

  local args = { n = select("#", ...), ... }
  local ok, result = xpcall(function()
    return EventBridge.RouteLiveEvent(runtime, refreshWindow, eventName, unpack(args, 1, args.n))
  end, reportError)
  if ok then
    return result
  end
  onIngestError(Bootstrap, runtime, direction, ...)
  return nil
end

ns.BootstrapWhisperIngestFailsafe = WhisperIngestFailsafe
return WhisperIngestFailsafe
