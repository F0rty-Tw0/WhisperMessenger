local Constants = require("WhisperMessenger.Core.Constants")

return function()
  -- LIFECYCLE_EVENT_NAMES contains BNet friend list events
  do
    assert(Constants.LIFECYCLE_EVENT_NAMES ~= nil, "LIFECYCLE_EVENT_NAMES should exist")
    local found = {}
    for _, name in ipairs(Constants.LIFECYCLE_EVENT_NAMES) do
      found[name] = true
    end
    assert(found["BN_FRIEND_LIST_SIZE_CHANGED"], "should include BN_FRIEND_LIST_SIZE_CHANGED")
    assert(found["BN_FRIEND_INFO_CHANGED"], "should include BN_FRIEND_INFO_CHANGED")
    assert(found["PLAYER_ENTERING_WORLD"], "should include PLAYER_ENTERING_WORLD")
  end

  -- ADDON_RESTRICTION_STATE_CHANGED is the authoritative resume signal on
  -- 12.0 clients — it must survive the mythic suspension unregister sweep,
  -- or a restriction ending while suspended is never noticed.
  do
    assert(Constants.MYTHIC_ESSENTIAL_EVENTS.ADDON_RESTRICTION_STATE_CHANGED == true, "ADDON_RESTRICTION_STATE_CHANGED should be mythic-essential")
  end
end
