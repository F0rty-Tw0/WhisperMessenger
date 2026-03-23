local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Retention = {}

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

  if now == nil then
    if type(_G.time) == "function" then
      now = _G.time()
    else
      now = os.time()
    end
  end

  for i = #messages, 1, -1 do
    local age = now - (messages[i].sentAt or 0)
    if age > maxAgeSeconds then
      table.remove(messages, i)
    end
  end

  return messages
end

function Retention.ExpireConversations(conversations, maxAgeSeconds, now)
  if type(maxAgeSeconds) ~= "number" then
    return conversations
  end

  if now == nil then
    if type(_G.time) == "function" then
      now = _G.time()
    else
      now = os.time()
    end
  end

  for key, conv in pairs(conversations) do
    if not conv.pinned then
      local age = now - (conv.lastActivityAt or 0)
      if age > maxAgeSeconds then
        conversations[key] = nil
      end
    end
  end

  return conversations
end

ns.Retention = Retention

return Retention
