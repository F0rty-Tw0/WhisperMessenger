local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Retention = {}

local function resolveNow(now)
  if now ~= nil then
    return now
  end

  if type(_G.time) == "function" then
    return _G.time()
  end

  return os.time()
end

function Retention.IsExpired(timestamp, maxAgeSeconds, now)
  if type(maxAgeSeconds) ~= "number" then
    return false
  end

  -- A record with no timestamp yet (freshly ensured conversation, message
  -- missing sentAt) is unknown-age, not infinitely old — keep it.
  if timestamp == nil or timestamp == 0 then
    return false
  end

  now = resolveNow(now)
  return now - timestamp > maxAgeSeconds
end

-- A queued message waits for the player's Send now / Discard click, so age
-- and count limits never drop it.
function Retention.IsQueued(message)
  return message.delivery == "queued"
end

function Retention.TrimMessages(messages, maxMessages)
  if type(maxMessages) ~= "number" or maxMessages < 1 then
    return messages
  end

  local total = #messages
  local excess = total - maxMessages
  if excess <= 0 then
    return messages
  end

  -- One O(n) compaction pass: drop the oldest non-queued messages.
  local writeIndex = 1
  for readIndex = 1, total do
    local message = messages[readIndex]
    if excess > 0 and not Retention.IsQueued(message) then
      excess = excess - 1
    else
      messages[writeIndex] = message
      writeIndex = writeIndex + 1
    end
  end
  for index = writeIndex, total do
    messages[index] = nil
  end

  return messages
end

function Retention.ExpireMessages(messages, maxAgeSeconds, now)
  if type(maxAgeSeconds) ~= "number" then
    return messages
  end

  now = resolveNow(now)
  local total = #messages
  local writeIndex = 1
  for readIndex = 1, total do
    local message = messages[readIndex]
    if Retention.IsQueued(message) or not Retention.IsExpired(message.sentAt, maxAgeSeconds, now) then
      messages[writeIndex] = message
      writeIndex = writeIndex + 1
    end
  end
  for index = writeIndex, total do
    messages[index] = nil
  end

  return messages
end

ns.Retention = Retention

return Retention
