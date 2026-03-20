-- Compatibility shim: allows require("WhisperMessenger.UI.ChatBubble") to
-- resolve to this directory. The facade lives in ChatBubble.lua.
return require("WhisperMessenger.UI.ChatBubble.ChatBubble")
