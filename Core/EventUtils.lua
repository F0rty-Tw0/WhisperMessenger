local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local EventUtils = {}

-- RegisterEvent throws "Attempt to register unknown event ..." on clients that
-- lack a given event (e.g. ADDON_RESTRICTION_STATE_CHANGED pre-12.0, or
-- CLUB_MEMBER_UPDATED on minimal Classic flavors). Detect those so callers can
-- skip silently while re-raising every other failure.
function EventUtils.IsUnknownEventError(err)
  return string.find(string.lower(tostring(err or "")), "unknown event", 1, true) ~= nil
end

function EventUtils.RegisterEventIfSupported(frame, eventName, onSkip)
  local ok, err = pcall(frame.RegisterEvent, frame, eventName)
  if ok then
    return true
  end
  if EventUtils.IsUnknownEventError(err) then
    if onSkip then
      onSkip(eventName)
    end
    return false
  end
  error(err)
end

ns.EventUtils = EventUtils

return EventUtils
