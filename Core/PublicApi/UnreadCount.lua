local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")
local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

-- GetUnreadCount(name): the number of unread whispers in the WoW chat with
-- that player, the same number the contact row shows. name is "Name-Realm",
-- or a bare "Name" when only one stored chat has that name. Muted chats and
-- message requests report their real count. A bad name (not a string, blank,
-- or secret), a name with no chat or more than one, or an internal error
-- returns 0; it never throws. Each call scans every stored chat, so call it
-- from onUnreadChanged or a repaint, never per frame.
local UnreadCount = {}

local floor = math.floor
local max = math.max

local function read(runtime, name)
  if SecretValue.Is(name) or not Guards.IsNonEmptyString(name) then
    return 0
  end
  local key = Identity.ResolveWhisperConversation(runtime, name, "WOW")
  local conversation = key and runtime.store.conversations[key]
  if not conversation then
    return 0
  end
  return max(0, floor(tonumber(conversation.unreadCount) or 0))
end

function UnreadCount.Install(api, runtime)
  api.GetUnreadCount = function(name)
    local ok, count = pcall(read, runtime, name)
    return ok and type(count) == "number" and count or 0
  end
end

ns.PublicApiUnreadCount = UnreadCount
return UnreadCount
