local EventUtils = require("WhisperMessenger.Core.EventUtils")

return function()
  -- IsUnknownEventError: matches Retail / Classic "unknown event" phrasing
  assert(EventUtils.IsUnknownEventError('Attempt to register unknown event "CLUB_MEMBER_UPDATED"'), "Retail-style unknown-event error should match")
  assert(
    EventUtils.IsUnknownEventError('Interface\\AddOns\\Foo\\Bar.lua:12: Attempt to register unknown event "X"'),
    "file-prefixed unknown-event error should match"
  )
  assert(EventUtils.IsUnknownEventError("UNKNOWN EVENT: X"), "uppercase unknown-event error should match (case-insensitive)")
  assert(EventUtils.IsUnknownEventError(nil) == false, "nil error should not match")
  assert(EventUtils.IsUnknownEventError("some other error") == false, "unrelated error should not match")
  assert(EventUtils.IsUnknownEventError("") == false, "empty string should not match")

  -- RegisterEventIfSupported: happy path
  do
    local registered = {}
    local frame = {
      RegisterEvent = function(self, eventName)
        registered[eventName] = true
      end,
    }
    local result = EventUtils.RegisterEventIfSupported(frame, "CHAT_MSG_WHISPER")
    assert(result == true, "RegisterEventIfSupported should return true on success")
    assert(registered.CHAT_MSG_WHISPER == true, "event should be registered")
  end

  -- RegisterEventIfSupported: unsupported event returns false without throwing
  do
    local frame = {
      RegisterEvent = function(_, eventName)
        error('Attempt to register unknown event "' .. eventName .. '"')
      end,
    }
    local result = EventUtils.RegisterEventIfSupported(frame, "CLUB_MEMBER_UPDATED")
    assert(result == false, "RegisterEventIfSupported should return false for unsupported events")
  end

  -- RegisterEventIfSupported: non-unknown-event errors propagate
  do
    local frame = {
      RegisterEvent = function()
        error("some other Blizzard failure")
      end,
    }
    local ok, err = pcall(EventUtils.RegisterEventIfSupported, frame, "CHAT_MSG_WHISPER")
    assert(ok == false, "RegisterEventIfSupported should re-raise non-unknown-event errors")
    assert(string.find(tostring(err), "some other Blizzard failure", 1, true) ~= nil, "original error message should be preserved")
  end
end
