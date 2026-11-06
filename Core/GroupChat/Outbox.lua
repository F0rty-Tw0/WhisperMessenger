local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AddonComm = ns.AddonComm or require("WhisperMessenger.Transport.AddonComm")
local GroupChatProtocol = ns.GroupChatProtocol or require("WhisperMessenger.Model.GroupChatProtocol")

-- Sends one group chat body to every member as addon whispers, frame by
-- frame. A frame the game refuses (the addon message throttle) waits a
-- second and is tried again, in order. A member the game reports offline
-- ("No player named ...") is skipped for a while, so a group with an
-- offline friend doesn't fill the chat with that line on every message;
-- anything they send clears it at once.
local Outbox = {}

Outbox.RETRY_DELAY = 1
Outbox.MAX_ATTEMPTS = 4
Outbox.OFFLINE_SKIP_SECONDS = 300
-- How long after a send the game's "not found" line is matched to it.
Outbox.NOT_FOUND_WINDOW = 5

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
    return addonComm.Send(chatApi, AddonComm.PREFIX_GROUP_CHAT, item.frame, item.target) == true
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
      if sendFrame(item) then
        table.remove(queue, 1)
        recentSends[key(item.target)] = { name = item.target, at = now() }
      else
        item.attempts = item.attempts + 1
        if item.attempts >= Outbox.MAX_ATTEMPTS then
          table.remove(queue, 1)
        else
          scheduleFlush()
          return
        end
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
  -- just sent to: skip them for a while. Returns their name, else nil.
  function outbox.ClaimNotFound(text)
    local template = _G.ERR_CHAT_PLAYER_NOT_FOUND_S
    if type(text) ~= "string" or type(template) ~= "string" then
      return nil
    end
    local current = now()
    for nameKey, sent in pairs(recentSends) do
      if current - sent.at > Outbox.NOT_FOUND_WINDOW then
        recentSends[nameKey] = nil
      elseif string.format(template, sent.name) == text or string.format(template, string.match(sent.name, "^[^%-]+")) == text then
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
