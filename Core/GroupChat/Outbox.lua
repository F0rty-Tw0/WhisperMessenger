local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AddonComm = ns.AddonComm or require("WhisperMessenger.Transport.AddonComm")
local GroupChatProtocol = ns.GroupChatProtocol or require("WhisperMessenger.Model.GroupChatProtocol")

-- Sends one group chat body to every member as addon whispers, frame by
-- frame. A frame the game throttles waits a second and is tried again, in
-- order; a frame it refuses for any other reason is dropped. A member the game reports offline
-- ("No player named ...") is skipped for a while, so a group with an
-- offline friend doesn't fill the chat with that line on every message;
-- anything they send clears it at once.
local Outbox = {}

Outbox.RETRY_DELAY = 1
Outbox.MAX_ATTEMPTS = 4
Outbox.OFFLINE_SKIP_SECONDS = 300
-- How long after a send the game's "not found" line is matched to it.
Outbox.NOT_FOUND_WINDOW = 5

-- A name for loose comparison: lower case, no spaces or hyphens.
function Outbox.LooseName(name)
  if type(name) ~= "string" then
    return nil
  end
  local ok, lowered = pcall(string.lower, name)
  if not ok then
    return nil
  end
  return (string.gsub(lowered, "[%s%-]", ""))
end

-- The name inside a system line built from template ("...'%s'..."), made
-- loose, or nil when the line is not that message.
function Outbox.NotFoundName(text, template)
  if type(text) ~= "string" or type(template) ~= "string" then
    return nil
  end
  local before, after = string.match(template, "^(.-)%%s(.*)$")
  if before == nil then
    return nil
  end
  if string.sub(text, 1, #before) ~= before or (#after > 0 and string.sub(text, -#after) ~= after) then
    return nil
  end
  local name = string.sub(text, #before + 1, #text - #after)
  if name == "" then
    return nil
  end
  return Outbox.LooseName(name)
end

local function key(name)
  local ok, lowered = pcall(string.lower, name)
  return ok and lowered or nil
end

-- options: chatApi (C_ChatInfo), addonComm, now(), timer (C_Timer), random.
function Outbox.New(options)
  options = options or {}
  local addonComm = options.addonComm or AddonComm
  local now = options.now or function()
    return 0
  end
  local timer = options.timer
  local random = options.random
  local chatApi = options.chatApi

  local outbox = {}
  local queue = {}
  local flushScheduled = false
  local counter = {}
  local offlineUntil = {}
  local recentSends = {}
  local prefixRegistered = false

  local function sendFrame(item)
    if not prefixRegistered then
      prefixRegistered = addonComm.RegisterPrefix(chatApi, AddonComm.PREFIX_GROUP_CHAT) == true
    end
    local sent, throttled = addonComm.SendWhisperDetailed(chatApi, AddonComm.PREFIX_GROUP_CHAT, item.frame, item.target)
    return sent == true, throttled == true
  end

  local flush
  local function scheduleFlush()
    if flushScheduled or timer == nil or type(timer.After) ~= "function" then
      return
    end
    flushScheduled = true
    timer.After(Outbox.RETRY_DELAY, function()
      flushScheduled = false
      flush()
    end)
  end

  flush = function()
    while queue[1] ~= nil do
      local item = queue[1]
      local sent, throttled = sendFrame(item)
      if sent then
        table.remove(queue, 1)
        recentSends[key(item.target)] = { name = item.target, at = now() }
      elseif throttled and item.attempts + 1 < Outbox.MAX_ATTEMPTS then
        item.attempts = item.attempts + 1
        scheduleFlush()
        return
      else
        table.remove(queue, 1)
      end
    end
  end

  function outbox.IsSkipped(name)
    local until_ = offlineUntil[key(name)]
    return until_ ~= nil and now() < until_
  end

  -- Queues body for every recipient not skipped as offline. Returns how
  -- many recipients it went to, or nil when the body cannot be framed.
  function outbox.Send(recipients, body)
    local frames = GroupChatProtocol.Split(body, GroupChatProtocol.NextMessageId(counter, random))
    if frames == nil then
      return nil
    end
    local wasIdle = queue[1] == nil
    local count = 0
    for _, target in ipairs(recipients or {}) do
      if not outbox.IsSkipped(target) then
        count = count + 1
        for _, frame in ipairs(frames) do
          queue[#queue + 1] = { target = target, frame = frame, attempts = 0 }
        end
      end
    end
    -- A queue already waiting on the throttle keeps its order: the new
    -- frames go out behind it on the next try.
    if wasIdle then
      flush()
    end
    return count
  end

  function outbox.MarkOnline(name)
    local nameKey = name and key(name)
    if nameKey then
      offlineUntil[nameKey] = nil
    end
  end

  -- The game's "No player named %s is currently playing." for someone we
  -- just sent to: skip them for a while. Returns their name, else nil. The
  -- name in the line is compared without case, spaces or hyphens: some
  -- clients print "Name Realm" for "Name-Realm".
  function outbox.ClaimNotFound(text)
    local named = Outbox.NotFoundName(text, _G.ERR_CHAT_PLAYER_NOT_FOUND_S)
    if named == nil then
      return nil
    end
    local current = now()
    for nameKey, sent in pairs(recentSends) do
      if current - sent.at > Outbox.NOT_FOUND_WINDOW then
        recentSends[nameKey] = nil
      elseif Outbox.LooseName(sent.name) == named or Outbox.LooseName(string.match(sent.name, "^[^%-]+")) == named then
        recentSends[nameKey] = nil
        offlineUntil[nameKey] = current + Outbox.OFFLINE_SKIP_SECONDS
        return sent.name
      end
    end
    return nil
  end

  -- True while a recent send could still be answered by "not found".
  function outbox.HasRecentSends()
    local current = now()
    for _, sent in pairs(recentSends) do
      if current - sent.at <= Outbox.NOT_FOUND_WINDOW then
        return true
      end
    end
    return false
  end

  function outbox.PendingCount()
    return #queue
  end

  return outbox
end

ns.GroupChatOutbox = Outbox
return Outbox
