-- Compatibility shim: allows require("WhisperMessenger.Model.Identity") to
-- resolve to this directory. The facade lives in Identity.lua.
return require("WhisperMessenger.Model.Identity.Identity")
