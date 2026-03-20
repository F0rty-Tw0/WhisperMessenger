-- Compatibility shim: allows require("WhisperMessenger.UI.MessengerWindow") to
-- resolve to this directory. The facade lives in MessengerWindow.lua.
return require("WhisperMessenger.UI.MessengerWindow.MessengerWindow")
