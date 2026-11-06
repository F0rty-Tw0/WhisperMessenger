local SeenByName = require("WhisperMessenger.Model.SeenByName")

return function()
  -- test_rerecording_a_name_does_not_use_cap_room
  do
    local limits = { MAX_ENTRIES = 2 }
    local store = SeenByName.New(limits)
    store.Put("Alice", "one")
    store.Put("Alice", "two")
    store.Put("Bob", "three")
    assert(store.Get("Alice") == "two", "a refreshed name must not count twice toward the cap")
    assert(store.Get("Bob") == "three", "second distinct name fits under the cap")
  end

  -- test_cap_is_read_live_from_limits
  do
    local limits = { MAX_ENTRIES = 5000 }
    local store = SeenByName.New(limits)
    store.Put("Alice", "one")
    limits.MAX_ENTRIES = 1
    store.Put("Bob", "two")
    assert(store.Get("Alice") == nil, "a lowered cap applies to the next new name")
    assert(store.Get("Bob") == "two", "the new name is stored after the wipe")
  end

  -- test_put_rejects_unkeyable_name
  do
    local store = SeenByName.New({ MAX_ENTRIES = 5 })
    assert(store.Put(nil, "x") == false, "a nil name is not stored")
    assert(store.Put({}, "x") == false, "a non-string name is not stored")
  end
end
