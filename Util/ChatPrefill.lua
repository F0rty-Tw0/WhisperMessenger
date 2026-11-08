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
-- command is safe to prefill only when the game already moved it securely
-- and nothing is waiting to be moved.
local function slashCommandSafe(text)
  local command = string.match(text, "^(/[^%s]+)")
  local hash = _G.hash_SlashCmdList
  local pending = _G.SlashCmdList
  local isSecure = _G.issecurevariable
  if command == nil or type(hash) ~= "table" or type(pending) ~= "table" or type(isSecure) ~= "function" then
    return false
  end
  local key = string.upper(command)
  if hash[key] == nil or next(pending) ~= nil then
    return false
  end

  return isSecure(hash, key) == true
end

-- Any error answers "not safe".
function ChatPrefill.IsSafe(text)
  local ok, safe = pcall(slashCommandSafe, text)

  return ok and safe == true
end

ns.ChatPrefill = ChatPrefill
return ChatPrefill
