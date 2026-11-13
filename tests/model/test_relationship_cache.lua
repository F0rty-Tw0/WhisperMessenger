local World = require("tests.helpers.relationship_world")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")
local Relationship = require("WhisperMessenger.Model.Relationship")

return function()
  -- test_cache_hit_calls_no_tie_api (a nil result is cached too)
  do
    local w = World.New()
    w.guildMembers["Arthas"] = true
    local hit, none = w.item("Player-1-AAA", "Arthas"), w.item("Player-1-BBB", "Jaina")
    Relationship.Resolve(hit, w.runtime)
    Relationship.Resolve(none, w.runtime)
    local after = w.totalCalls()
    local again = Relationship.Resolve(hit, w.runtime)
    assert(again and again.primary == "guild", "cached value returned")
    assert(Relationship.Resolve(none, w.runtime) == nil, "cached 'no tie' returned")
    assert(w.totalCalls() == after, "warm cache makes zero tie API calls")
  end

  -- AC 5: warm refresh of 50 contacts = 0 calls; cold = at most 4 per contact
  do
    local w = World.New()
    local items = {}
    for i = 1, 50 do
      items[i] = w.item("Player-1-" .. i, "Name" .. i)
    end
    for _, item in ipairs(items) do
      Relationship.Resolve(item, w.runtime)
    end
    assert(w.totalCalls() <= 50 * 4, "cold resolve costs at most 4 calls per contact, got " .. w.totalCalls())
    local cold, coldNames = w.totalCalls(), w.playerInfoCalls
    for _, item in ipairs(items) do
      Relationship.Resolve(item, w.runtime)
    end
    assert(w.totalCalls() == cold, "warm refresh must make zero tie API calls")
    assert(w.playerInfoCalls == coldNames, "warm refresh must not look up names, got " .. (w.playerInfoCalls - coldNames))
  end

  -- test_entry_expires_after_300_seconds
  do
    local w = World.New()
    local item = w.item("Player-1-AAA", "Arthas")
    Relationship.Resolve(item, w.runtime)
    local after = w.totalCalls()
    w.now = 1299
    Relationship.Resolve(item, w.runtime)
    assert(w.totalCalls() == after, "299 s old entry still hits")
    w.now = 1300
    Relationship.Resolve(item, w.runtime)
    assert(w.totalCalls() > after, "300 s old entry re-resolves")
  end

  -- test_index_generation_change_drops_cache
  do
    local w = World.New()
    local item = w.item("Player-1-AAA", "Arthas")
    Relationship.Resolve(item, w.runtime)
    local after = w.totalCalls()
    PresenceCache.Rebuild()
    Relationship.Resolve(item, w.runtime)
    assert(w.totalCalls() > after, "a PresenceCache rebuild must drop the cache")
  end

  -- test_invalidate_forces_fresh_resolve
  do
    local w = World.New()
    w.guildMembers["Arthas"] = true
    local item = w.item("Player-1-AAA", "Arthas")
    Relationship.Resolve(item, w.runtime)
    w.guildMembers["Arthas"] = nil
    assert(Relationship.Resolve(item, w.runtime) ~= nil, "still cached before Invalidate")
    Relationship.Invalidate(w.runtime)
    assert(next(w.runtime.relationshipCache) == nil, "Invalidate empties the cache table")
    assert(Relationship.Resolve(item, w.runtime) == nil, "fresh resolve after Invalidate sees the new answer")
  end

  -- BNet chat: key includes playerGuid, so a character switch misses; a hit still calls the account lookup but no tie API
  do
    local w = World.New()
    w.guildMembers["Frodo"] = true
    w.setBNet(7, { characterName = "Frodo", playerGuid = "Player-1-BNF" })
    local chat = w.bnItem(7)
    Relationship.Resolve(chat, w.runtime)
    local guildCalls, accountCalls, nameCalls = w.calls.guild, w.calls.account, w.playerInfoCalls
    Relationship.Resolve(chat, w.runtime)
    assert(w.calls.guild == guildCalls, "BNet chat hit calls no tie API")
    assert(w.playerInfoCalls == nameCalls, "BNet chat hit does not look up the character name")
    assert(w.calls.account > accountCalls, "BNet chat hit still asks the account lookup for its key")
    w.setBNet(7, { characterName = "Sam", playerGuid = "Player-1-SAM" })
    Relationship.Resolve(chat, w.runtime)
    assert(w.calls.guild == guildCalls + 1, "a character switch misses the cache")
  end

  -- test_is_enabled
  do
    assert(Relationship.IsEnabled({}) == true, "no accountState -> on")
    assert(Relationship.IsEnabled({ accountState = { settings = {} } }) == true, "missing key -> on")
    assert(Relationship.IsEnabled({ accountState = { settings = { showRelationshipMarks = false } } }) == false, "false -> off")
    assert(Relationship.IsEnabled({ accountState = { settings = { showRelationshipMarks = true } } }) == true, "true -> on")
  end

  -- test_tooltip_lines_text_and_order
  do
    local full = { primary = "bnet", ties = { "bnet", "guild", "friend", "community" }, guildName = "Moonwatch", communityName = "Trade Hall" }
    local lines = Relationship.TooltipLines(full)
    assert(table.concat(lines, "|") == "Battle.net friend|Guild: Moonwatch|Friend|Community: Trade Hall", "got " .. table.concat(lines, "|"))
    local bare = { primary = "guild", ties = { "guild", "community" } }
    assert(table.concat(Relationship.TooltipLines(bare), "|") == "Guild|Community", "no names -> bare labels")
    assert(#Relationship.TooltipLines(nil) == 0, "nil rel -> no lines")
  end

  print("  All Relationship cache tests passed")
end
