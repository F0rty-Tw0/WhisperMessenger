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

ns.Retention = Retention

return Retention
