local Constants = require("WhisperMessenger.Core.Constants")

return function()
  -- LIFECYCLE_EVENT_NAMES contains BNet friend list events
  do
    assert(Constants.LIFECYCLE_EVENT_NAMES ~= nil, "LIFECYCLE_EVENT_NAMES should exist")
    local found = {}
    for _, name in ipairs(Constants.LIFECYCLE_EVENT_NAMES) do
      found[name] = true
    end
    assert(found["BN_FRIEND_LIST_AVAILABLE"], "should include BN_FRIEND_LIST_AVAILABLE")
    assert(found["BN_FRIEND_INFO_CHANGED"], "should include BN_FRIEND_INFO_CHANGED")
    assert(found["PLAYER_ENTERING_WORLD"], "should include PLAYER_ENTERING_WORLD")
  end
end
