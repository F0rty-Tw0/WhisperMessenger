-- Compatibility shim: allows require("WhisperMessenger.Model.ContactEnricher") to
-- resolve to this directory. The facade lives in ContactEnricher.lua.
return require("WhisperMessenger.Model.ContactEnricher.ContactEnricher")
