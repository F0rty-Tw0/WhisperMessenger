local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Grouping = {}

function Grouping.ShouldGroup(prev, current)
  if not prev or not current then
    return false
  end
  if prev.direction ~= current.direction then
    return false
  end
  if prev.kind == "system" or current.kind == "system" then
    return false
  end
  if (prev.playerName or prev.senderDisplayName) ~= (current.playerName or current.senderDisplayName) then
    return false
  end
  if math.abs((current.sentAt or 0) - (prev.sentAt or 0)) > 120 then
    return false
  end
  return true
end

ns.ChatBubbleGrouping = Grouping
return Grouping
