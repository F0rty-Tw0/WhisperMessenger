local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Opens the game's chat box with text for the player to send. The game focuses
-- the box before the text lands, so while this runs our own edit-box hooks
-- must leave the box alone: a whisper target still sitting in it would
-- otherwise pull the prefill into the messenger.
local ChatPrefill = {}

local opening = false

-- Current Retail has ChatFrameUtil.OpenChat; older clients and the Classic
-- flavors have the ChatFrame_OpenChat global. Neither → nil.
function ChatPrefill.Resolve()
  local util = _G.ChatFrameUtil
  if type(util) == "table" and type(util.OpenChat) == "function" then
    return util.OpenChat
  end
  if type(_G.ChatFrame_OpenChat) == "function" then
    return _G.ChatFrame_OpenChat
  end

  return nil
end

function ChatPrefill.Open(text)
  local openChat = ChatPrefill.Resolve()
  if openChat == nil then
    return
  end
  opening = true
  local ok, err = pcall(openChat, text)
  opening = false
  if not ok then
    error(err, 0)
  end
end

function ChatPrefill.IsOpening()
  return opening
end

-- Opening the box from addon code makes the game parse the text under the
-- addon's taint, and that parse moves every pending slash command (raw
-- SlashCmdList entries) into hash_SlashCmdList. Done under our taint, the
-- moved handlers stay tainted and the game blocks the protected call they
-- make when the player presses Enter (ADDON_ACTION_FORBIDDEN). So a slash
-- command is safe to prefill only when nothing is waiting to be moved and the
-- game already moved it securely. Protected commands (/use, /target) sit in
-- the game's own private table, which addons cannot change, so for them the
-- empty queue is enough.
local function slashCommandSafe(text)
  local command = string.match(text, "^(/[^%s]+)")
  local hash = _G.hash_SlashCmdList
  local pending = _G.SlashCmdList
  local isSecure = _G.issecurevariable
  if command == nil or type(pending) ~= "table" or next(pending) ~= nil then
    return false
  end
  if ChatPrefill.IsProtectedCommand(command) then
    return true
  end
  if type(hash) ~= "table" or type(isSecure) ~= "function" then
    return false
  end
  local key = string.upper(command)
  if hash[key] == nil then
    return false
  end

  return isSecure(hash, key) == true
end

-- Any error answers "not safe".
function ChatPrefill.IsSafe(text)
  local ok, safe = pcall(slashCommandSafe, text)

  return ok and safe == true
end

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
