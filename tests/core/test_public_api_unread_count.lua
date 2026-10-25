local PublicApi = require("WhisperMessenger.Core.PublicApi")

local JAINA = "wow::WOW::jaina-proudmoore"

local function makeRuntime()
  return {
    store = {
      conversations = {
        [JAINA] = { channel = "WOW", displayName = "Jaina-Proudmoore", unreadCount = 3 },
        ["wow::WOW::thrall-area52"] = { channel = "WOW", displayName = "Thrall-Area52", unreadCount = 2.7 },
        ["wow::WOW::bob-a"] = { channel = "WOW", displayName = "Bob-A", unreadCount = 1 },
        ["wow::WOW::bob-b"] = { channel = "WOW", displayName = "Bob-B", unreadCount = 1 },
        ["wow::WOW::zed-area52"] = { channel = "WOW", displayName = "Zed-Area52" },
      },
    },
  }
end

local function build()
  local runtime = makeRuntime()
  return PublicApi.Build(runtime), runtime
end

return function()
  -- test_full_name_returns_the_stored_count
  do
    local api = build()
    assert(api.GetUnreadCount("Jaina-Proudmoore") == 3, "got " .. tostring(api.GetUnreadCount("Jaina-Proudmoore")))
  end

  -- test_unique_base_name_returns_the_stored_count
  do
    local api = build()
    assert(api.GetUnreadCount("Jaina") == 3)
  end

  -- test_fractional_count_is_floored
  do
    local api = build()
    assert(api.GetUnreadCount("Thrall-Area52") == 2)
  end

  -- test_missing_count_returns_zero
  do
    local api = build()
    assert(api.GetUnreadCount("Zed-Area52") == 0)
  end

  -- test_ambiguous_base_name_returns_zero
  do
    local api = build()
    assert(api.GetUnreadCount("Bob") == 0)
  end

  -- test_unknown_name_returns_zero
  do
    local api = build()
    assert(api.GetUnreadCount("Nobody-Realm") == 0)
  end

  -- test_bad_names_return_zero
  do
    local api = build()
    assert(api.GetUnreadCount(nil) == 0, "nil")
    assert(api.GetUnreadCount(42) == 0, "number")
    assert(api.GetUnreadCount("   ") == 0, "blank")
  end

  -- test_secret_name_returns_zero
  do
    local saved = rawget(_G, "issecretvalue")
    local api = build()
    rawset(_G, "issecretvalue", function(value)
      return value == "Jaina-Proudmoore"
    end)
    local count = api.GetUnreadCount("Jaina-Proudmoore")
    rawset(_G, "issecretvalue", saved)
    assert(count == 0, "secret name must not resolve, got " .. tostring(count))
  end

  -- test_negative_count_clamps_to_zero
  do
    local api, runtime = build()
    runtime.store.conversations[JAINA].unreadCount = -4
    assert(api.GetUnreadCount("Jaina-Proudmoore") == 0)
  end

  -- test_internal_error_returns_zero
  do
    local api, runtime = build()
    runtime.store = setmetatable({}, {
      __index = function()
        error("boom")
      end,
    })
    assert(api.GetUnreadCount("Jaina-Proudmoore") == 0)
  end
end
