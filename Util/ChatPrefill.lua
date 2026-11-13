local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Slash-command checks for text the player will send through the game's own
-- chat box. Addon code never fills that box: the game blocks the player's
-- Enter on a box the addon opened (seen in game for /use and /ginvite), so
-- callers show the command in the copy dialog instead.
local ChatPrefill = {}

-- True when the game lists the text's command as protected (/use, /target,
-- /cast, ...): addon code running it gets blocked. Any error answers "no".
function ChatPrefill.IsProtectedCommand(text)
  if type(text) ~= "string" or type(_G.IsSecureCmd) ~= "function" then
    return false
  end
  local command = string.match(text, "^(/[^%s]+)")
  if command == nil then
    return false
  end
  local ok, protected = pcall(_G.IsSecureCmd, command)

  return ok and protected == true
end

ns.ChatPrefill = ChatPrefill
return ChatPrefill
