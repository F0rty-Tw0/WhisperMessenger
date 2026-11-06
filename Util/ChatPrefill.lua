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

ns.ChatPrefill = ChatPrefill
return ChatPrefill
