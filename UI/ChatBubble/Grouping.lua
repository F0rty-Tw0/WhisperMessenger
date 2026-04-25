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
  if prev.kind == "channel_context" or current.kind == "channel_context" then
    return false
  end
  if (prev.playerName or prev.senderDisplayName) ~= (current.playerName or current.senderDisplayName) then
    return false
  end
  -- Outgoing messages from different characters (alts) must not group, even
  -- inside the time window. Otherwise the new character's bubble silently
  -- inherits the previous group's "· <CharName>" suffix and class icon —
  -- visible after a relog when no incoming reply has broken the group.
  if prev.direction == "out" and (prev.senderName or "") ~= (current.senderName or "") then
    return false
  end
  if math.abs((current.sentAt or 0) - (prev.sentAt or 0)) > 120 then
    return false
  end
  return true
end

ns.ChatBubbleGrouping = Grouping
return Grouping
