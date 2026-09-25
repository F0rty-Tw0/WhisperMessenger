local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Opt-in Requests inbox: a new character whisper from someone who is not a
-- friend, a Battle.net friend's character, a guildmate or a group member is
-- flagged once, at creation. The flag only counts while the setting is on.
-- Every identity check fails open: unknown means NOT a request, so a real
-- whisper is never hidden.
local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")

local MessageRequests = {}

function MessageRequests.IsRequest(conversation, settings)
  return type(conversation) == "table" and conversation.request == true and type(settings) == "table" and settings.requestsInbox == true
end

-- true = related, false = not related, nil = unknown (API missing or threw,
-- e.g. a secret value during chat lockdown).
local function ask(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, related = pcall(function(...)
    return fn(...) and true or false
  end, ...)
  if not ok then
    return nil
  end
  return related
end

-- Every check must positively answer "no".
local function isStranger(runtime, guid, name)
  if type(guid) ~= "string" or guid == "" or type(name) ~= "string" or name == "" then
    return false
  end
  local friendListApi = runtime.friendListApi or {}
  local bnetApi = runtime.bnetApi or {}
  local unitName = Identity.ShortName(name)
  local answers = {
    ask(friendListApi.IsFriend, guid),
    ask(bnetApi.GetGameAccountInfoByGUID, guid),
    ask(_G.IsGuildMember, guid),
    ask(_G.UnitInParty, unitName),
    ask(_G.UnitInRaid, unitName),
  }
  for index = 1, 5 do
    if answers[index] ~= false then
      return false
    end
  end
  -- GUID group check catches members whose name form the unit lookups miss.
  -- Only a missing API is skipped; an error still fails open.
  if type(_G.IsGUIDInGroup) == "function" and ask(_G.IsGUIDInGroup, guid) ~= false then
    return false
  end
  return true
end

-- Called once, right after a character whisper created the conversation (so
-- it cannot be pinned, nicknamed or written in yet).
function MessageRequests.ClassifyNew(runtime, conversation, guid, name)
  local settings = runtime and runtime.accountState and runtime.accountState.settings
  if type(conversation) ~= "table" or type(settings) ~= "table" or settings.requestsInbox ~= true then
    return
  end
  if conversation.channel == "BN" then
    return
  end
  if isStranger(runtime, guid, name) then
    conversation.request = true
  end
end

function MessageRequests.Accept(store, conversationKey)
  local conversation = Store.Find(store, conversationKey)
  if conversation then
    conversation.request = nil
  end
end

ns.MessageRequests = MessageRequests
return MessageRequests
