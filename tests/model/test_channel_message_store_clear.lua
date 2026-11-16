local ChannelMessageStore = require("WhisperMessenger.Model.ChannelMessageStore")

local function textOf(state, name, now)
  local entry = ChannelMessageStore.GetLatest(state, name, now)
  return entry and entry.text or nil
end

local function build()
  local state = ChannelMessageStore.New({ maxEntries = 3 })
  ChannelMessageStore.Record(state, "Thrall-Realm", "WTS sword", "Trade", 100)
  ChannelMessageStore.Record(state, "Jaina-Realm", "LF healer", "LookingForGroup", 200)
  return state
end

return function()
  -- test_clear_drops_every_recorded_line
  do
    local state = build()
    ChannelMessageStore.Clear(state)

    assert(next(state.entries) == nil and state.entryCount == 0, "no line is left to save")
    assert(textOf(state, "thrall-realm") == nil and textOf(state, "jaina") == nil, "lookups find nothing, by full name or by name only")
  end

  -- test_clear_keeps_the_saved_table_and_its_settings
  do
    local state = build()
    local sequence = state.nextSequence
    ChannelMessageStore.Clear(state)

    assert(state.maxEntries == 3 and state.ttl ~= nil, "limits are kept")
    assert(state.nextSequence == sequence, "the arrival counter never goes back")
  end

  -- test_store_records_and_evicts_normally_after_clear
  do
    local state = build()
    ChannelMessageStore.Clear(state)
    for index = 1, 4 do
      ChannelMessageStore.Record(state, "Player" .. index .. "-Realm", "line " .. index, "Trade", 300 + index)
    end

    assert(state.entryCount == 3, "the cap counts only lines recorded after the clear")
    assert(textOf(state, "player1-realm") == nil, "the oldest new line is evicted")
    assert(textOf(state, "player4") == "line 4", "a new line is found by name only")
  end

  -- test_clear_on_an_empty_store_is_a_no_op
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Clear(state)
    assert(next(state.entries) == nil and state.entryCount == 0)
  end
end
