local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Addon notices in the default chat frame, with the gold addon prefix.
local ChatPrint = {}

local PREFIX = "|cffffd100WhisperMessenger:|r "

-- frame: optional chat frame; the default chat frame otherwise.
function ChatPrint.Print(text, frame)
  frame = frame or _G.DEFAULT_CHAT_FRAME
  if frame == nil or type(frame.AddMessage) ~= "function" then
    return false
  end
  frame:AddMessage(PREFIX .. text)
  return true
end

ns.ChatPrint = ChatPrint
return ChatPrint
