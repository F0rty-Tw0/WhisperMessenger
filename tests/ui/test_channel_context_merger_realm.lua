local ChannelContextMerger = require("WhisperMessenger.UI.ConversationPane.ChannelContextMerger")
local ChannelMessageStore = require("WhisperMessenger.Model.ChannelMessageStore")

local NOW = 10000

-- A whisper partner on your own realm arrives without a realm, so the lookup
-- must add your realm before asking the store.
local SAME_REALM_CONTACT = { displayName = "Thrall", channel = "WOW" }

local function makeDeps(state)
  return {
    channelMessageStore = ChannelMessageStore,
    channelMessageState = state,
    now = NOW,
  }
end

local function mergeFor(contact, sender)
  local state = ChannelMessageStore.New()
  ChannelMessageStore.Record(state, sender, "WTS ore", "Trade", 9500)
  return ChannelContextMerger.Merge({}, contact, makeDeps(state))
end

local function withRealm(realm, fn)
  local saved = rawget(_G, "GetNormalizedRealmName")
  rawset(_G, "GetNormalizedRealmName", realm and function()
    return realm
  end or nil)
  local ok, err = pcall(fn)
  rawset(_G, "GetNormalizedRealmName", saved)
  if not ok then
    error(err, 0)
  end
end

return function()
  -- test_same_realm_contact_ignores_same_name_from_another_realm
  withRealm("Area52", function()
    local result = mergeFor(SAME_REALM_CONTACT, "Thrall-Draenor")
    assert(#result == 0, "a same-realm contact must not take another realm's line, got " .. tostring(result[1] and result[1].text))
  end)

  -- test_same_realm_contact_finds_its_own_realm_line
  withRealm("Area52", function()
    local result = mergeFor(SAME_REALM_CONTACT, "Thrall-Area52")
    assert(#result == 1 and result[1].text == "WTS ore", "a same-realm contact should find its own realm's line")
  end)

  -- test_same_realm_contact_finds_a_realmless_line
  withRealm("Area52", function()
    local result = mergeFor(SAME_REALM_CONTACT, "Thrall")
    assert(#result == 1 and result[1].text == "WTS ore", "a same-realm contact should find a realm-less line")
  end)

  -- test_cross_realm_contact_keeps_its_own_realm_line
  withRealm("Area52", function()
    local result = mergeFor({ displayName = "Thrall-Draenor", channel = "WOW" }, "Thrall-Draenor")
    assert(#result == 1 and result[1].text == "WTS ore", "a contact that has a realm must keep it, not get yours")
  end)

  -- test_without_own_realm_the_lookup_stays_bare
  withRealm(nil, function()
    local result = mergeFor(SAME_REALM_CONTACT, "Thrall-Draenor")
    assert(#result == 1, "with no realm known, a bare lookup keeps the newest line from any realm")
  end)

  -- test_bnet_contact_lookup_is_not_given_your_realm
  withRealm("Area52", function()
    -- A Battle.net friend can play on any realm, so a bare name stays bare.
    local result = mergeFor({ displayName = "Thrall", channel = "BN" }, "Thrall-Draenor")
    assert(#result == 1, "a Battle.net contact's bare name must not get your realm")
  end)
end
