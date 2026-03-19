local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = {}

local function normalizeName(name)
  return string.lower(name or "")
end

function Identity.FromWhisper(fullName, guid)
  return {
    channel = "WOW",
    contactKey = "WOW::" .. normalizeName(fullName),
    canonicalName = normalizeName(fullName),
    displayName = fullName,
    guid = guid,
  }
end

function Identity.BuildConversationKey(localProfileId, contactKey)
  return localProfileId .. "::" .. contactKey
end

ns.Identity = Identity

return Identity
