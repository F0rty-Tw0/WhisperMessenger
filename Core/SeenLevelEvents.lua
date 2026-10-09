local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local SeenLevel = ns.SeenLevel or require("WhisperMessenger.Model.SeenLevel")
local WhoLookup = ns.WhoLookup or require("WhisperMessenger.Transport.WhoLookup")

-- Records the levels the game shows the player (target, mouseover,
-- nameplates, group, friends) and pushes them to saved whisper chats.
-- Owns its frame so these events never pass through the lifecycle router.
local SeenLevelEvents = {}

SeenLevelEvents.UNIT_EVENTS = {
  "PLAYER_TARGET_CHANGED",
  "UPDATE_MOUSEOVER_UNIT",
  "NAME_PLATE_UNIT_ADDED",
  "UNIT_LEVEL",
  "GROUP_ROSTER_UPDATE",
  "FRIENDLIST_UPDATE",
}

-- Registered only inside WhoLookup's who window.
SeenLevelEvents.WHO_EVENTS = {
  "WHO_LIST_UPDATE",
  "CHAT_MSG_SYSTEM",
}

---@type table|nil
local runtime = nil
local enabled = false
local capturing = false

local function push(name, level)
  local nameKey = SeenLevel.NameKey(name)
  if runtime == nil or nameKey == nil then
    return
  end
  local key = Identity.BuildConversationKey(runtime.localProfileId, "WOW::" .. nameKey)
  local conversation = Store.Find(runtime.store, key)
  if conversation == nil or conversation.channel == "BN" or conversation.characterLevel == level then
    return
  end
  conversation.characterLevel = level
  local schedule = runtime.scheduleIncomingRefresh
  if schedule then
    schedule(key)
  end
end

local function record(guid, name, level)
  if SeenLevel.Record(guid, name, level) and name ~= nil then
    push(name, level)
  end
end

-- Runs under pcall: 12.0 secret unit values throw on comparison.
local function recordUnit(unit)
  if not _G.UnitIsPlayer(unit) then
    return
  end
  local guid = _G.UnitGUID(unit)
  local level = _G.UnitLevel(unit)
  if type(level) ~= "number" or level <= 0 then
    return
  end
  if guid ~= nil and SeenLevel.Get(guid) == level then
    return
  end
  local name, realm = _G.UnitFullName(unit)
  -- A half-loaded unit has no real name yet; the next sighting retries.
  if name == nil or name == "" or name == _G.UNKNOWNOBJECT then
    return
  end
  if realm ~= nil and realm ~= "" then
    name = name .. "-" .. realm
  end
  record(guid, name, level)
end

local function recordGroup()
  local count = _G.GetNumGroupMembers()
  local prefix, last = "party", count - 1
  if _G.IsInRaid() then
    prefix, last = "raid", count
  end
  for i = 1, last do
    pcall(recordUnit, prefix .. i)
  end
end

local function recordFriends(api)
  if not (api and api.GetNumFriends and api.GetFriendInfoByIndex) then
    return
  end
  for i = 1, api.GetNumFriends() do
    local info = api.GetFriendInfoByIndex(i)
    if info and info.connected then
      record(info.guid, info.name, info.level)
    end
  end
end

local function recordWho(api)
  if not (api and api.GetNumWhoResults and api.GetWhoInfo) then
    return
  end
  for i = 1, api.GetNumWhoResults() do
    local info = api.GetWhoInfo(i)
    if info then
      record(nil, info.fullName, info.level)
    end
  end
end

local function captureBlocked(rt)
  return (rt.isCompetitiveContent and rt.isCompetitiveContent()) or (rt.isMythicLockdown and rt.isMythicLockdown())
end

local function dispatch(rt, event, unit)
  if event == "PLAYER_TARGET_CHANGED" then
    pcall(recordUnit, "target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    pcall(recordUnit, "mouseover")
  elseif event == "NAME_PLATE_UNIT_ADDED" or event == "UNIT_LEVEL" then
    pcall(recordUnit, unit)
  elseif event == "GROUP_ROSTER_UPDATE" then
    pcall(recordGroup)
  elseif event == "FRIENDLIST_UPDATE" then
    pcall(recordFriends, rt.friendListApi)
  elseif event == "WHO_LIST_UPDATE" or event == "CHAT_MSG_SYSTEM" then
    pcall(recordWho, rt.friendListApi)
  end
end

-- Only WHO_LIST_UPDATE answers our query: an unrelated system line must not
-- end it. Ending it even when blocked or the read failed restores FriendsFrame
-- now instead of at the window timeout.
local function onEvent(_self, event, unit)
  local rt = runtime
  if rt == nil then
    return
  end
  if not captureBlocked(rt) then
    dispatch(rt, event, unit)
  end
  if event == "WHO_LIST_UPDATE" then
    WhoLookup.OnWhoListUpdate()
  end
end

function SeenLevelEvents.Init(rt)
  runtime = rt
  if SeenLevelEvents._frame == nil then
    local frame = _G.CreateFrame("Frame")
    frame:SetScript("OnEvent", onEvent)
    SeenLevelEvents._frame = frame
  end
end

local function unregisterAll()
  local frame = SeenLevelEvents._frame
  if frame and frame.UnregisterAllEvents then
    frame:UnregisterAllEvents()
  end
  capturing = false
end

function SeenLevelEvents.SetEnabled(on)
  enabled = on == true
  if not enabled then
    unregisterAll()
    return
  end
  local frame = SeenLevelEvents._frame
  if frame == nil or _G._wmSuspended then
    return
  end
  for _, event in ipairs(SeenLevelEvents.UNIT_EVENTS) do
    frame:RegisterEvent(event)
  end
  capturing = true
  -- Turned back on while a query is in flight: its result must still be read.
  if WhoLookup.IsWindowOpen and WhoLookup.IsWindowOpen() then
    SeenLevelEvents.OpenWhoWindow()
  end
end

-- No-op unless capture is live: enabled and not blocked by _wmSuspended.
function SeenLevelEvents.OpenWhoWindow()
  local frame = SeenLevelEvents._frame
  if not capturing or frame == nil then
    return
  end
  for _, event in ipairs(SeenLevelEvents.WHO_EVENTS) do
    frame:RegisterEvent(event)
  end
end

function SeenLevelEvents.CloseWhoWindow()
  local frame = SeenLevelEvents._frame
  if frame == nil or not frame.UnregisterEvent then
    return
  end
  for _, event in ipairs(SeenLevelEvents.WHO_EVENTS) do
    frame:UnregisterEvent(event)
  end
end

function SeenLevelEvents.IsEnabled()
  return enabled
end

function SeenLevelEvents._reset()
  unregisterAll()
  runtime = nil
  enabled = false
end

ns.SeenLevelEvents = SeenLevelEvents

return SeenLevelEvents
