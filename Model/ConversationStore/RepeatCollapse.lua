local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- In-place repeat of a stored message: counts it up and stamps when it was
-- last seen. No new row, no unread change.
local RepeatCollapse = {}

function RepeatCollapse.CollapseRepeat(state, key, message, sentAt)
  message.repeatCount = (message.repeatCount or 1) + 1
  message.lastSeenAt = sentAt
  local conversation = state.conversations and state.conversations[key]
  if conversation ~= nil then
    conversation.lastActivityAt = sentAt
  end
end

ns.ConversationStoreRepeatCollapse = RepeatCollapse
return RepeatCollapse
