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

  now = resolveNow(now)
  return now - (timestamp or 0) > maxAgeSeconds
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

  -- Shift tail down in one O(n) pass instead of O(n) table.remove(t, 1) calls
  for i = 1, maxMessages do
    messages[i] = messages[excess + i]
  end
  for i = maxMessages + 1, total do
    messages[i] = nil
  end

  return messages
end

function Retention.ExpireMessages(messages, maxAgeSeconds, now)
  if type(maxAgeSeconds) ~= "number" then
    return messages
  end

  now = resolveNow(now)

  for i = #messages, 1, -1 do
    if Retention.IsExpired(messages[i].sentAt, maxAgeSeconds, now) then
      table.remove(messages, i)
    end
  end

  return messages
end

function Retention.ExpireConversations(conversations, maxAgeSeconds, now)
  if type(maxAgeSeconds) ~= "number" then
    return conversations
  end

  now = resolveNow(now)

  for key, conv in pairs(conversations) do
    if not conv.pinned and Retention.IsExpired(conv.lastActivityAt, maxAgeSeconds, now) then
      conversations[key] = nil
    end
  end

  return conversations
end


ns.Retention = Retention

return Retention
