local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local DataBuilder = {}

local ConversationSnapshot = ns.ConversationSnapshot or require("WhisperMessenger.Model.ConversationSnapshot")

local function compareItems(left, right)
  local leftPinned = left.pinned and true or false
  local rightPinned = right.pinned and true or false
  if leftPinned ~= rightPinned then
    return leftPinned
  end

  -- sortOrder only applies within the pinned group
  if leftPinned and rightPinned then
    local leftOrder = left.sortOrder or 0
    local rightOrder = right.sortOrder or 0
    if leftOrder ~= 0 or rightOrder ~= 0 then
      if leftOrder ~= rightOrder then
        if leftOrder == 0 then
          return false
        end
        if rightOrder == 0 then
          return true
        end
        return leftOrder < rightOrder
      end
    end
  end

  if left.lastActivityAt ~= right.lastActivityAt then
    return left.lastActivityAt > right.lastActivityAt
  end

  return (left.displayName or "") < (right.displayName or "")
end

function DataBuilder.BuildItems(conversations)
  local items = {}

  for conversationKey, conversation in pairs(conversations or {}) do
    table.insert(items, ConversationSnapshot.Build(conversationKey, conversation))
  end

  table.sort(items, compareItems)
  return items
end

-- Per-character group key prefixes: the conversation key has the shape
-- "<prefix><localProfileId>", so we match them by joining the prefix with
-- the current character's profile. This keeps other characters' guild /
-- party / raid threads out of this character's contacts list.
local PER_CHARACTER_GROUP_PREFIXES = {
  "guild::",
  "officer::",
  "party::",
  "raid::",
  "instance::",
}

-- Account-wide group prefixes: keys use their own IDs and are shared across
-- all characters on the account.
local ACCOUNT_GROUP_PREFIXES = {
  "bnconv::",
  "community::",
}

local function resolvePlayerGuildName()
  local getGuildInfo = _G.GetGuildInfo
  if type(getGuildInfo) ~= "function" then
    return nil
  end
  local ok, name = pcall(getGuildInfo, "player")
  if not ok then
    return nil
  end
  if type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

local function resolveGuildOwnership(conversation, conversationKey, localProfileId)
  -- Account-wide guild keys store the guild name directly on the record,
  -- so whichever character is logged in just needs to compare their live
  -- guild name. Fall back to the per-character key shape for legacy
  -- conversations that pre-date account-wide guild storage.
  if conversation and type(conversation.guildName) == "string" and conversation.guildName ~= "" then
    local playerGuild = resolvePlayerGuildName()
    if playerGuild and string.lower(playerGuild) == string.lower(conversation.guildName) then
      return nil, nil -- current char is in this guild — not foreign
    end
    local ownerProfileId = conversation.ownerProfileId
    return ownerProfileId, ownerProfileId
  end

  -- Legacy per-character shape: "guild::<profileId>".
  local keyOwner = string.sub(conversationKey, 8) -- strip "guild::"
  if keyOwner == "" then
    return nil, nil
  end
  if keyOwner == localProfileId then
    return nil, keyOwner
  end
  return keyOwner, keyOwner
end

function DataBuilder.BuildItemsForProfile(savedState, localProfileId)
  local items = {}
  local profilePrefix = localProfileId .. "::"
  local bnetPrefix = "bnet::"
  local wowPrefix = "wow::"
  local playerClasses = savedState.playerClasses or {}

  for conversationKey, conversation in pairs(savedState.conversations or {}) do
    local include = false
    -- foreignOwner is set when a per-character group chat is owned by a
    -- different character than the current login. UI uses this hint to
    -- annotate the row (e.g. "Jaina — Guild") so the player can tell
    -- which alt's history they're looking at.
    local foreignOwner = nil
    -- ownerClassTag is the class tag of the character that owns the
    -- group conversation (always the originating character, whether
    -- that's the current login or another alt). Used to tint the row
    -- title with the owner's class color.
    local ownerClassTag = nil

    if
      string.find(conversationKey, profilePrefix, 1, true) == 1
      or string.find(conversationKey, bnetPrefix, 1, true) == 1
      or string.find(conversationKey, wowPrefix, 1, true) == 1
    then
      include = true
    end

    if not include then
      if string.find(conversationKey, "guild::", 1, true) == 1 then
        include = true
        local ownerId
        foreignOwner, ownerId = resolveGuildOwnership(conversation, conversationKey, localProfileId)
        if foreignOwner == nil and ownerId == nil then
          -- Current character is in this guild — tint by current class.
          ownerClassTag = playerClasses[localProfileId] or nil
        elseif ownerId then
          ownerClassTag = playerClasses[ownerId] or nil
        end
      end
    end

    if not include then
      for _, prefix in ipairs(PER_CHARACTER_GROUP_PREFIXES) do
        if prefix ~= "guild::" and string.find(conversationKey, prefix, 1, true) == 1 then
          include = true
          local keyOwner = string.sub(conversationKey, #prefix + 1)
          if keyOwner ~= nil and keyOwner ~= "" then
            if keyOwner ~= localProfileId then
              foreignOwner = keyOwner
            end
            ownerClassTag = playerClasses[keyOwner] or nil
          end
          break
        end
      end
    end

    if not include then
      for _, prefix in ipairs(ACCOUNT_GROUP_PREFIXES) do
        if string.find(conversationKey, prefix, 1, true) == 1 then
          include = true
          break
        end
      end
    end

    if include then
      local snapshot = ConversationSnapshot.Build(conversationKey, conversation)
      snapshot.ownerProfileId = foreignOwner
      snapshot.ownerClassTag = ownerClassTag
      table.insert(items, snapshot)
    end
  end

  table.sort(items, compareItems)
  return items
end

ns.ContactsListDataBuilder = DataBuilder
return DataBuilder
