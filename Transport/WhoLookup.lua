local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local SeenLevel = ns.SeenLevel or require("WhisperMessenger.Model.SeenLevel")
local WhoFreshness = ns.WhoFreshness or require("WhisperMessenger.Transport.WhoFreshness")
local WhoBlock = ns.WhoBlock or require("WhisperMessenger.Transport.WhoBlock")
local WhoPanels = ns.WhoPanels or require("WhisperMessenger.Transport.WhoPanels")

-- A quiet /who for a whisper contact whose level, zone and guild are older
-- than STALE_SECONDS (or never fetched). SendWho is protected: it works only
-- synchronously inside a hardware event (a click or a key press), never from
-- a timer. WhoPanels keeps the game's Who panels out of it while in flight.
local WhoLookup = {}

WhoLookup.WINDOW_SECONDS = 5
WhoLookup.MIN_GAP_SECONDS = 5
WhoLookup.STALE_SECONDS = WhoFreshness.STALE_SECONDS

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
-- The "Look up players with /who" option; a missing saved key counts as on.
local lookupsEnabled = true

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
  WhoPanels.Release(previousWhoToUi)
end

-- Our /who will get no answer, so its name counts as never asked.
local function forgetInFlight()
  inFlight = false
  if inFlightNameKey ~= nil then
    lastAskedAt[inFlightNameKey] = nil
  end
  cleanup()
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
    forgetInFlight()
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

function WhoLookup.SetEnabled(on)
  lookupsEnabled = on ~= false
end

function WhoLookup.IsEnabled()
  return lookupsEnabled
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
    forgetInFlight()
  end
  if not lookupsEnabled then
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

local isBlocked = WhoBlock.IsBlocked

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
  previousWhoToUi = false -- kept if Claim throws
  previousWhoToUi = WhoPanels.Claim()
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
  if rt == nil or not lookupsEnabled then
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
  if rt == nil or not lookupsEnabled or type(name) ~= "string" then
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
  lookupsEnabled = true
end

ns.WhoLookup = WhoLookup

return WhoLookup
