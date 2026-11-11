local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local DisplayName = ns.DisplayName or require("WhisperMessenger.Util.DisplayName")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local SeenLevel = ns.SeenLevel or require("WhisperMessenger.Model.SeenLevel")
local WhoFreshness = ns.WhoFreshness or require("WhisperMessenger.Transport.WhoFreshness")

-- A quiet /who for a whisper contact whose level, zone and guild are older
-- than STALE_SECONDS (or never fetched). SendWho is protected: it works only
-- synchronously inside a hardware event (a click or a key press), never from
-- a timer.
-- FriendsFrame pops the Who window on WHO_LIST_UPDATE, and on WoW: Forever
-- so does the Group Finder's Who tab, so their event stays unregistered
-- while our query is in flight.
local WhoLookup = {}

WhoLookup.WINDOW_SECONDS = 5
WhoLookup.MIN_GAP_SECONDS = 5
WhoLookup.STALE_SECONDS = WhoFreshness.STALE_SECONDS

local WHO_EVENT = "WHO_LIST_UPDATE"
local WHO_LISTENERS = { "FriendsFrame", "LFGWhoListFrame" }
local WHO_PANELS = { "WhoFrame", "LFGWhoListFrame" }

---@type table|nil
local runtime = nil
local hooked = false
local windowOpen = false
local closesAt = 0
local windowTimer = nil
local inFlight = false
local inFlightNameKey = nil
local lastSentAt = nil
local previousWhoToUi = false
local lastAskedAt = {}
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

local function setWhoListeners(method)
  for _, name in ipairs(WHO_LISTENERS) do
    local frame = _G[name]
    if frame and frame[method] then
      frame[method](frame, WHO_EVENT)
    end
  end
end

-- IsVisible, not IsShown: a closed parent leaves its Who tab shown.
local function whoPanelVisible()
  for _, name in ipairs(WHO_PANELS) do
    local frame = _G[name]
    if frame and frame.IsVisible and frame:IsVisible() == true then
      return true
    end
  end
  return false
end

local function cleanup()
  setWhoListeners("RegisterEvent")
  -- Keep the flag on while a Who panel is on screen.
  local api = _G.C_FriendList
  if api and api.SetWhoToUi then
    api.SetWhoToUi(whoPanelVisible() or previousWhoToUi)
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
  -- No answer: the server drops a /who sent too soon after another, so the
  -- name was never really asked and the next click may try again.
  if inFlight then
    inFlight = false
    if inFlightNameKey ~= nil then
      lastAskedAt[inFlightNameKey] = nil
    end
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
-- Mythic+ runs no addon code, so a suspended hook does nothing.
-- A foreign one ends ours at once so the player's query behaves normally;
-- ours then never gets its answer, so the name counts as not asked.
local function onSendWho()
  if _G._wmSuspended then
    return
  end
  lastSentAt = now(runtime)
  if inFlight and not sendingOurs then
    inFlight = false
    if inFlightNameKey ~= nil then
      lastAskedAt[inFlightNameKey] = nil
    end
    cleanup()
  end
  if not DisplayName.ShowPlayerLevels() then
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

-- Returns the name to ask about and its conversation, or nil when this
-- contact is not a WoW chat with a name.
local function lookupName(rt, conversationKey)
  local conversation = Store.Find(rt.store, conversationKey)
  if conversation == nil or conversation.channel ~= "WOW" then
    return nil
  end
  local name = conversation.displayName
  if type(name) ~= "string" then
    return nil
  end
  return name, conversation
end

local function sendQuery(shortName)
  setWhoListeners("UnregisterEvent")
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

local function ask(rt, name, conversation)
  local nameKey = SeenLevel.NameKey(name)
  if nameKey == nil or WhoFreshness.IsFresh(conversation, name, lastAskedAt[nameKey], now(rt)) then
    return false
  end
  if isBlocked(rt) or isThrottled(rt) then
    return false
  end
  lastAskedAt[nameKey] = now(rt)
  lastSentAt = now(rt)
  inFlight = true
  inFlightNameKey = nameKey
  local ok = pcall(sendQuery, string.match(name, "^[^-]+") or name)
  sendingOurs = false
  if not ok then
    inFlight = false
    pcall(cleanup)
  end
  return ok
end

function WhoLookup.TryFor(rt, conversationKey)
  if rt == nil or not DisplayName.ShowPlayerLevels() then
    return false
  end
  local name, conversation = lookupName(rt, conversationKey)
  if name == nil then
    return false
  end
  return ask(rt, name, conversation)
end

-- For a chat the game hands over a frame after the click: its conversation
-- may not exist yet, and a missing one counts as never asked.
function WhoLookup.TryForName(rt, name, conversationKey)
  if rt ~= nil and Store.Find(rt.store, conversationKey) ~= nil then
    return WhoLookup.TryFor(rt, conversationKey)
  end
  if rt == nil or not DisplayName.ShowPlayerLevels() or type(name) ~= "string" then
    return false
  end
  if string.find(name, "|K", 1, true) then
    return false
  end
  return ask(rt, name, {})
end

-- A plain, visible /who for a shift-clicked name: the result shows like a
-- typed one. Our hooks and FriendsFrame stay out of it; the SendWho hook
-- stamps lastSentAt. Must run inside the click itself.
function WhoLookup.SendVisible(name)
  if runtime == nil or type(name) ~= "string" or name == "" then
    return false
  end
  if string.find(name, "|K", 1, true) then
    return false
  end
  if isBlocked(runtime) or isThrottled(runtime) then
    return false
  end
  local shortName = string.match(name, "^[^-]+") or name
  local ok = pcall(_G.C_FriendList.SendWho, 'n-"' .. shortName .. '"')

  return ok
end

function WhoLookup._reset()
  runtime = nil
  hooked = false
  windowOpen = false
  closesAt = 0
  windowTimer = nil
  inFlight = false
  inFlightNameKey = nil
  lastSentAt = nil
  previousWhoToUi = false
  lastAskedAt = {}
  sendingOurs = false
end

ns.WhoLookup = WhoLookup

return WhoLookup
