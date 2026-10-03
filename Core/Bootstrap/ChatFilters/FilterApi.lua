local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FilterApi = {}

-- Route Blizzard filter-table mutations through `securecall` so the write
-- happens inside Blizzard's own function body, not in our addon stack.
-- Without this, the filter table becomes tainted; the next CHAT_MSG_WHISPER
-- dispatch iterates the tainted table and propagates taint into
-- ChatEdit_SetLastTellTarget, crashing /r, R-keybind, and right-click-Whisper
-- during encounters or after returning from Mythic+ / PvP content.
local function secureCallBlizzard(fn, ...)
  local sc = _G.securecall
  if type(sc) == "function" then
    return sc(fn, ...)
  end
  return fn(...)
end

-- ChatFrameUtil is the current API; the ChatFrame_* globals are deprecated
-- aliases kept for older clients.
local function resolve(utilName, globalName)
  local util = _G.ChatFrameUtil
  if type(util) == "table" and type(util[utilName]) == "function" then
    return util[utilName]
  end
  local legacy = _G[globalName]
  if type(legacy) == "function" then
    return legacy
  end
  return nil
end

local function call(utilName, globalName, event, fn)
  local target = resolve(utilName, globalName)
  if not target then
    return false
  end
  secureCallBlizzard(target, event, fn)
  return true
end

function FilterApi.Add(event, fn)
  return call("AddMessageEventFilter", "ChatFrame_AddMessageEventFilter", event, fn)
end

function FilterApi.Remove(event, fn)
  return call("RemoveMessageEventFilter", "ChatFrame_RemoveMessageEventFilter", event, fn)
end

function FilterApi.IsAvailable()
  return resolve("AddMessageEventFilter", "ChatFrame_AddMessageEventFilter") ~= nil
end

ns.BootstrapChatFilterApi = FilterApi
return FilterApi
