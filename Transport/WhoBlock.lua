local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- When a quiet /who must not go out: combat, the chat lock, Mythic+ and
-- competitive content.
local WhoBlock = {}

function WhoBlock.IsBlocked(rt)
  if _G.InCombatLockdown and _G.InCombatLockdown() then
    return true
  end
  local chatInfo = _G.C_ChatInfo
  if chatInfo and chatInfo.InChatMessagingLockdown and chatInfo.InChatMessagingLockdown() then
    return true
  end
  if rt.isMythicLockdown and rt.isMythicLockdown() then
    return true
  end
  -- Without NewTimer the window never closes and cleanup never runs.
  local timers = _G.C_Timer
  if not (timers and timers.NewTimer) then
    return true
  end
  return (rt.isCompetitiveContent and rt.isCompetitiveContent()) == true
end

ns.WhoBlock = WhoBlock

return WhoBlock
