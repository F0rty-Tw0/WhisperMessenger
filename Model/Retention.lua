local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Retention = {}

function Retention.TrimMessages(messages, maxMessages)
  if type(maxMessages) ~= "number" or maxMessages < 1 then
    return messages
  end

  while #messages > maxMessages do
    table.remove(messages, 1)
  end

  return messages
end

ns.Retention = Retention

return Retention
