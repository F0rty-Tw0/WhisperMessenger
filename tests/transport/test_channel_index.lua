local ChannelIndex = require("WhisperMessenger.Transport.ChannelIndex")

-- Channel numbers change with join order, so a channel chat finds its live
-- number by name at send time and never trusts a stored one.
local function withGlobals(values, fn)
  local saved = {}
  for _, name in ipairs({ "GetChannelList", "GetChannelName" }) do
    saved[name] = rawget(_G, name)
    rawset(_G, name, values[name])
  end
  local ok, err = pcall(fn)
  for name, value in pairs(saved) do
    rawset(_G, name, value)
  end
  assert(ok, err)
end

local unpackList = table.unpack or unpack

local function channelList(...)
  local list = { ... }
  return function()
    return unpackList(list)
  end
end

return function()
  -- test_finds_live_number_after_renumber
  withGlobals({ GetChannelList = channelList(1, "General", false, 2, "LookingForGroup", false, 4, "Trade", false) }, function()
    assert(ChannelIndex.Resolve("Trade - Stormwind City") == 4, "Trade is found at its live number")
  end)

  -- test_zone_suffix_is_ignored_on_both_sides
  withGlobals({ GetChannelList = channelList(1, "General - Elwynn Forest", false) }, function()
    assert(ChannelIndex.Resolve("General - Stormwind City") == 1, "General matches across zones")
  end)

  -- test_disabled_channel_cannot_be_sent_to
  withGlobals({ GetChannelList = channelList(2, "Trade", true) }, function()
    assert(ChannelIndex.Resolve("Trade - City") == nil, "a disabled channel resolves to nothing")
  end)

  -- test_left_channel_resolves_to_nothing
  withGlobals({ GetChannelList = channelList(1, "General", false) }, function()
    assert(ChannelIndex.Resolve("CraftScan") == nil, "a channel the player left resolves to nothing")
  end)

  -- test_name_lookup_when_no_channel_list
  withGlobals({
    GetChannelName = function(name)
      return name == "CraftScan" and 5 or 0
    end,
  }, function()
    assert(ChannelIndex.Resolve("CraftScan") == 5, "the name lookup finds the channel")
    assert(ChannelIndex.Resolve("Gone") == nil, "an unknown name resolves to nothing")
  end)

  -- test_throwing_api_resolves_to_nothing
  withGlobals({
    GetChannelList = function()
      error("unavailable")
    end,
  }, function()
    assert(ChannelIndex.Resolve("Trade") == nil, "a throwing channel list resolves to nothing")
  end)

  -- test_no_api_resolves_to_nothing
  withGlobals({}, function()
    assert(ChannelIndex.Resolve("Trade") == nil, "without channel APIs nothing resolves")
    assert(ChannelIndex.Resolve(nil) == nil, "no name resolves to nothing")
  end)
end
