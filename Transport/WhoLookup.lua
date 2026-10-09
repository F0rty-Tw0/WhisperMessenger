local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local DisplayName = ns.DisplayName or require("WhisperMessenger.Util.DisplayName")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local SeenLevel = ns.SeenLevel or require("WhisperMessenger.Model.SeenLevel")

-- A quiet /who for a whisper contact whose level is unknown, once per name
-- per session. SendWho is protected: it works only synchronously inside a
-- hardware event (a click or a key press), never from a timer.
-- FriendsFrame pops the Who window on WHO_LIST_UPDATE, so its event stays
-- unregistered while our query is in flight.
local WhoLookup = {}

WhoLookup.WINDOW_SECONDS = 5
WhoLookup.MIN_GAP_SECONDS = 5

local WHO_EVENT = "WHO_LIST_UPDATE"

---@type table|nil
local runtime = nil
local hooked = false
local windowOpen = false
local closesAt = 0
local windowTimer = nil
local inFlight = false
local lastSentAt = nil
local previousWhoToUi = false
local askedThisSession = {}
local sendingOurs = false

-- The client clock: runtime.now is whole-second time(), which can read a
-- 4 s gap as 5 s.
local function now(rt)
  if type(_G.GetTime) == "function" then
    return _G.GetTime()
  end
  return rt and type(rt.now) == "function" and rt.now() or 0
end

local function whoWindowCall(method)
  local events = runtime and runtime.seenLevelEvents
  if events and events[method] then
    events[method]()
  end
end

local function cleanup()
  local frame = _G.FriendsFrame
  if frame and frame.RegisterEvent then
    frame:RegisterEvent(WHO_EVENT)
  end
  local api = _G.C_FriendList
  if api and api.SetWhoToUi then
    api.SetWhoToUi(previousWhoToUi)
  end
end

local function startTimer(seconds, callback)
  local timers = _G.C_Timer
  if timers and timers.NewTimer then
    windowTimer = timers.NewTimer(seconds, callback)
  end
end

-- closesAt guards a timer that outlived its Cancel: it re-arms for the rest.
local function onWindowExpired()
  windowTimer = nil
  local remaining = runtime and closesAt - now(runtime) or 0
  if remaining > 0 then
    startTimer(remaining, onWindowExpired)
    return
  end
  windowOpen = false
  whoWindowCall("CloseWhoWindow")
  if inFlight then
    inFlight = false
    cleanup()
  end
end

function WhoLookup.OpenWindow()
  if runtime == nil then
    return
  end
  closesAt = now(runtime) + WhoLookup.WINDOW_SECONDS
  windowOpen = true
  if windowTimer and windowTimer.Cancel then
    windowTimer:Cancel()
  end
  startTimer(WhoLookup.WINDOW_SECONDS, onWindowExpired)
  whoWindowCall("OpenWhoWindow")
end

function WhoLookup.IsWindowOpen()
  return windowOpen
end

function WhoLookup.OnWhoListUpdate()
  if not inFlight then
    return
  end
  inFlight = false
  local timers = _G.C_Timer
  if timers and timers.After then
    timers.After(0, cleanup)
  else
    cleanup()
  end
end

-- Runs after every SendWho, ours included: the server throttles them all.
-- A foreign one ends ours at once so the player's query behaves normally.
local function onSendWho()
  lastSentAt = now(runtime)
  if inFlight and not sendingOurs then
    inFlight = false
    cleanup()
  end
  if _G._wmSuspended or not DisplayName.ShowPlayerLevels() then
    return
  end
  WhoLookup.OpenWindow()
end

function WhoLookup.Init(rt)
  runtime = rt
  if hooked or type(_G.hooksecurefunc) ~= "function" then
    return
  end
  local api = _G.C_FriendList
  if type(api) ~= "table" or type(api.SendWho) ~= "function" then
    return
  end
  _G.hooksecurefunc(api, "SendWho", onSendWho)
  hooked = true
end

local function isBlocked(rt)
  if _G.InCombatLockdown and _G.InCombatLockdown() then
    return true
  end
  local chatInfo = _G.C_ChatInfo
  if chatInfo and chatInfo.InChatMessagingLockdown and chatInfo.InChatMessagingLockdown() then
    return true
  end
  if rt.isMythicLockdown and rt.isMythicLockdown() then
    return true
  end
  -- Without NewTimer the window never closes and cleanup never runs.
  local timers = _G.C_Timer
  if not (timers and timers.NewTimer) then
    return true
  end
  return (rt.isCompetitiveContent and rt.isCompetitiveContent()) == true
end

local function isThrottled(rt)
  if inFlight or windowOpen then
    return true
  end
  return lastSentAt ~= nil and now(rt) - lastSentAt < WhoLookup.MIN_GAP_SECONDS
end

-- Returns the name to ask about, or nil when this contact needs no /who.
local function lookupName(rt, conversationKey)
  local conversation = Store.Find(rt.store, conversationKey)
  if conversation == nil or conversation.channel ~= "WOW" then
    return nil
  end
  local name = conversation.displayName
  if type(name) ~= "string" or conversation.characterLevel ~= nil then
    return nil
  end
  if SeenLevel.Get(conversation.guid, name) ~= nil then
    return nil
  end
  return name
end

local function sendQuery(shortName)
  local frame = _G.FriendsFrame
  if frame and frame.UnregisterEvent then
    frame:UnregisterEvent(WHO_EVENT)
  end
  local api = _G.C_FriendList
  previousWhoToUi = false
  if api.GetWhoToUi then
    previousWhoToUi = api.GetWhoToUi() or false
  end
  api.SetWhoToUi(true)
  WhoLookup.OpenWindow()
  sendingOurs = true
  _G.C_FriendList.SendWho('n-"' .. shortName .. '"')
end

function WhoLookup.TryFor(rt, conversationKey)
  if rt == nil or not DisplayName.ShowPlayerLevels() then
    return false
  end
  local name = lookupName(rt, conversationKey)
  if name == nil then
    return false
  end
  local nameKey = SeenLevel.NameKey(name)
  if nameKey == nil or askedThisSession[nameKey] then
    return false
  end
  if isBlocked(rt) or isThrottled(rt) then
    return false
  end
  askedThisSession[nameKey] = true
  lastSentAt = now(rt)
  inFlight = true
  local ok = pcall(sendQuery, string.match(name, "^[^-]+") or name)
  sendingOurs = false
  if not ok then
    inFlight = false
    pcall(cleanup)
  end
  return ok
end

function WhoLookup._reset()
  runtime = nil
  hooked = false
  windowOpen = false
  closesAt = 0
  windowTimer = nil
  inFlight = false
  lastSentAt = nil
  previousWhoToUi = false
  askedThisSession = {}
  sendingOurs = false
end

ns.WhoLookup = WhoLookup

return WhoLookup
