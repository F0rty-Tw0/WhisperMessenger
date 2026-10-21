local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

local SecretString = {}

-- In 12.0 Midnight, event payloads inside encounters / restricted actions
-- can carry "secret string" values (GUID, sender name, message text). Any
-- operation on them from an addon-tainted frame (==, string.lower,
-- table.concat) throws `a secret string value tainted by 'WhisperMessenger'`.
-- Ask issecretvalue instead of trying a comparison: a pcall hides the error,
-- but the game still logs every blocked comparison in taint.log.
local isSecretString = SecretValue.Is

-- PayloadHasSecretFields checks whether any taint-sensitive field in the
-- payload is a 12.0 secret string. Accepts an optional detectOverride so
-- tests can swap the detector (the real WoW "secret string" type cannot
-- be simulated from plain Lua).
function SecretString.PayloadHasSecretFields(payload, detectOverride)
  -- Dispatch through the override so tests can swap the detector
  -- (the real WoW "secret string" type cannot be simulated from plain Lua).
  local detect = detectOverride or isSecretString
  if detect(payload.text) then
    return true
  end
  if detect(payload.playerName) then
    return true
  end
  if detect(payload.guid) then
    return true
  end
  return false
end

-- Exposed so the facade can re-export it as GroupChatIngest._isSecretString
SecretString.IsSecretString = isSecretString

ns.GroupChatIngestSecretString = SecretString

return SecretString
