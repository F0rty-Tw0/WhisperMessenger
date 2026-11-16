local Queries = require("WhisperMessenger.Core.PublicApi.Queries")

local NAMES = { "SetContactInfo", "GetUnreadCount", "GetLook", "IsAnimationEnabled", "IsCompactWindow", "InsertLink" }

return function()
  -- test_install_adds_every_query_as_a_function
  do
    local api = {}
    Queries.Install(api, {})
    for _, name in ipairs(NAMES) do
      assert(type(api[name]) == "function", name .. " should be installed")
    end
  end

  -- test_install_adds_nothing_else
  do
    local api = {}
    Queries.Install(api, {})
    local count = 0
    for _ in pairs(api) do
      count = count + 1
    end
    assert(count == #NAMES, "expected " .. #NAMES .. " entries, got " .. count)
  end

  -- test_install_keeps_entries_already_on_the_table
  do
    local open = function() end
    local api = { version = 1, OpenConversation = open }
    Queries.Install(api, {})
    assert(api.version == 1 and api.OpenConversation == open, "earlier entries stay untouched")
  end
end
