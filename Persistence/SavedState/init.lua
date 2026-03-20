-- Compatibility shim: allows require("WhisperMessenger.Persistence.SavedState") to
-- resolve to this directory. The facade lives in SavedState.lua.
return require("WhisperMessenger.Persistence.SavedState.SavedState")
