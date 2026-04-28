local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SecretString = {}

-- In 12.0 Midnight, event payloads inside encounters / restricted actions
-- can carry "secret string" values (GUID, sender name, message text). Any
-- operation on them from an addon-tainted frame (==, string.lower,
-- table.concat) throws `a secret string value tainted by 'WhisperMessenger'`.
-- Detect via pcall on a cheap comparison; if it throws the value is secret.
local function rawStringCompare(value)
  return value == ""
end

local function isSecretString(value)
  if value == nil then
    return false
  end
  if type(value) ~= "string" then
    return false
  end
  local ok = pcall(rawStringCompare, value)
  return not ok
end

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
