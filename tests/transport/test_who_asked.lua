local WhoAsked = require("WhisperMessenger.Transport.WhoAsked")
local WhoFreshness = require("WhisperMessenger.Transport.WhoFreshness")

local function case(fn)
  WhoAsked._reset()
  local maxEntries = WhoAsked.MAX_ENTRIES
  local ok, err = pcall(fn)
  WhoAsked.MAX_ENTRIES = maxEntries
  WhoAsked._reset()
  assert(ok, err)
end

return function()
  -- test_remember_stores_the_ask_time_once_per_name
  case(function()
    assert(WhoAsked.Get("jaina") == nil and WhoAsked.Count() == 0, "nothing is remembered at first")
    WhoAsked.Remember("jaina", 100)
    WhoAsked.Remember("jaina", 200)
    assert(WhoAsked.Get("jaina") == 200, "the latest ask time wins")
    assert(WhoAsked.Count() == 1, "asking the same name again adds no entry")
  end)

  -- test_forget_drops_the_name
  case(function()
    WhoAsked.Remember("jaina", 100)
    WhoAsked.Forget("jaina")
    WhoAsked.Forget("jaina")
    WhoAsked.Forget(nil)
    assert(WhoAsked.Get("jaina") == nil and WhoAsked.Count() == 0, "a forgotten name counts as never asked")
  end)

  -- test_cap_drops_only_names_past_the_freshness_window
  case(function()
    WhoAsked.MAX_ENTRIES = 3
    WhoAsked.Remember("old", 0)
    WhoAsked.Remember("recent", WhoFreshness.STALE_SECONDS - 10)
    WhoAsked.Remember("newer", WhoFreshness.STALE_SECONDS - 5)

    WhoAsked.Remember("newest", WhoFreshness.STALE_SECONDS)

    assert(WhoAsked.Get("old") == nil, "a name asked a full window ago is dropped")
    assert(WhoAsked.Get("recent") ~= nil and WhoAsked.Get("newer") ~= nil, "names still inside the window stay")
    assert(WhoAsked.Get("newest") == WhoFreshness.STALE_SECONDS and WhoAsked.Count() == 3, "the new name is remembered")
  end)

  -- test_cap_holds_when_every_name_is_fresh
  case(function()
    WhoAsked.MAX_ENTRIES = 3
    for index = 1, 10 do
      WhoAsked.Remember("name" .. index, index)
      assert(WhoAsked.Count() <= 3, "never more than the cap, got " .. WhoAsked.Count())
    end
    assert(WhoAsked.Get("name10") == 10, "the name just asked is always kept")
  end)

  -- test_below_the_cap_nothing_is_dropped
  case(function()
    WhoAsked.Remember("old", 0)
    WhoAsked.Remember("new", WhoFreshness.STALE_SECONDS * 5)
    assert(WhoAsked.Get("old") == 0 and WhoAsked.Count() == 2, "stale names stay until the cap is reached")
  end)
end
