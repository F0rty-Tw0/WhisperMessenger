-- Compatibility shim: allows require("WhisperMessenger.UI.ContactsList") to
-- resolve to this directory. The facade lives in ContactsList.lua.
return require("WhisperMessenger.UI.ContactsList.ContactsList")
