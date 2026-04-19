local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Common = ns.BootstrapLifecycleHandlersCommon
  or (type(require) == "function" and require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common"))
  or nil

local GroupMembership = {}

-- Label shown as a system message when the player leaves a given group type.
local LEFT_LABEL = {
  PARTY = "Left party.",
  INSTANCE_CHAT = "Left instance.",
  RAID = "Left raid.",
}

local function currentTime()
  if type(_G.time) == "function" then
    return _G.time() or 0
  end
  return 0
end

local function appendLeftMessage(conversation, channel, now)
  conversation.messages = conversation.messages or {}
  local text = LEFT_LABEL[channel] or "Left group."
  table.insert(conversation.messages, {
    id = tostring(now) .. "-left-" .. channel,
    kind = "system",
    direction = "in",
    text = text,
    sentAt = now,
    channel = channel,
  })
  conversation.lastActivityAt = now
  conversation.lastPreview = text
end

-- Conversation keys for per-character group chats look like
-- "<prefix><profileId>" (e.g. "party::jaina-proudmoore"). The GroupRoster
-- event only tells us about the *current* character's party/raid/instance
-- state, so we must only mark transitions on the conversations that
-- belong to the current character. Touching every character's group
-- conversation would mis-flip `leftGroup` on alts' history whenever the
-- current character's group state changed.
local CHANNEL_KEY_PREFIX = {
  PARTY = "party::",
  RAID = "raid::",
  INSTANCE_CHAT = "instance::",
}

-- handleGroupRosterUpdate fires on GROUP_ROSTER_UPDATE.
-- Instead of purging party/instance/raid conversations when the player leaves,
-- we keep the history, append a "Left <channel>." system message, and mark
-- the conversation so sending is blocked until the next join (ChatGateway.CanSend
-- already returns false for channels the player is no longer in, so the
-- composer notice "Not in group — can't send." surfaces automatically).
-- Classic compat: if IsInGroup is nil, skip entirely.
function GroupMembership.handleGroupRosterUpdate(Bootstrap, deps)
  if _G.IsInGroup == nil then
    return true
  end

  local runtime = Bootstrap.runtime
  local state = runtime and (runtime.accountState or runtime.store)
  if state == nil or state.conversations == nil then
    return true
  end

  local localProfileId = runtime and runtime.localProfileId
  if type(localProfileId) ~= "string" or localProfileId == "" then
    -- Without a profileId we can't reliably scope the transition to the
    -- current character; bail rather than risk flipping foreign history.
    return true
  end

  local inGroup = {
    PARTY = _G.IsInGroup(_G.LE_PARTY_CATEGORY_HOME) and true or false,
    INSTANCE_CHAT = _G.IsInGroup(_G.LE_PARTY_CATEGORY_INSTANCE) and true or false,
    RAID = (type(_G.IsInRaid) == "function" and _G.IsInRaid()) and true or false,
  }

  local now = currentTime()
  local changed = false

  for channel, membership in pairs(inGroup) do
    local prefix = CHANNEL_KEY_PREFIX[channel]
    if prefix then
      local key = prefix .. localProfileId
      local conversation = state.conversations[key]
      if conversation ~= nil then
        if membership then
          if conversation.leftGroup then
            conversation.leftGroup = nil
            changed = true
          end
        else
          if not conversation.leftGroup then
            appendLeftMessage(conversation, channel, now)
            conversation.leftGroup = true
            changed = true
          end
        end
      end
    end
  end

  if changed then
    if deps and deps.trace then
      deps.trace("GroupMembership: marked group membership transition(s)")
    end
    if Common and Common.refreshRuntimeWindow then
      Common.refreshRuntimeWindow(Bootstrap)
    end
  end

  return true
end

ns.BootstrapLifecycleHandlersGroupMembership = GroupMembership
return GroupMembership
