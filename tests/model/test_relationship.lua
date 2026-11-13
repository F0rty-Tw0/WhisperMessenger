local World = require("tests.helpers.relationship_world")
local Relationship = require("WhisperMessenger.Model.Relationship")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")

local function tiesOf(rel)
  return rel and table.concat(rel.ties, ",") or "nil"
end

return function()
  -- test_each_tie_alone
  do
    local w = World.New()
    w.guildMembers["Arthas"] = true
    local rel = Relationship.Resolve(w.item("Player-1-AAA", "Arthas"), w.runtime)
    assert(tiesOf(rel) == "guild" and rel.primary == "guild", "guild alone, got " .. tiesOf(rel))
    assert(rel.guildName == "Moonwatch", "guildName from GetGuildInfo")

    w = World.New()
    w.bnetByGuid["Player-1-AAA"] = { bnetAccountID = 7 }
    assert(tiesOf(Relationship.Resolve(w.item("Player-1-AAA", "Arthas"), w.runtime)) == "bnet", "bnet alone")

    w = World.New()
    w.friendGuids["Player-1-AAA"] = true
    assert(tiesOf(Relationship.Resolve(w.item("Player-1-AAA", "Arthas"), w.runtime)) == "friend", "friend by guid")

    w = World.New()
    w.friendNames["Arthas"] = true
    assert(tiesOf(Relationship.Resolve(w.item("Player-1-AAA", "Arthas"), w.runtime)) == "friend", "friend by name fallback")

    w = World.New()
    w.setCommunity("Player-1-AAA", 5, "Trade Hall")
    rel = Relationship.Resolve(w.item("Player-1-AAA", "Arthas"), w.runtime)
    assert(tiesOf(rel) == "community" and rel.communityName == "Trade Hall", "community alone with its name")
  end

  -- test_priority_order_when_several_apply
  do
    local w = World.New()
    w.guildMembers["Arthas"] = true
    w.bnetByGuid["Player-1-AAA"] = {}
    w.friendGuids["Player-1-AAA"] = true
    w.setCommunity("Player-1-AAA", 5, "Trade Hall")
    local rel = Relationship.Resolve(w.item("Player-1-AAA", "Arthas"), w.runtime)
    assert(tiesOf(rel) == "bnet,guild,friend,community" and rel.primary == "bnet", "priority order, got " .. tiesOf(rel))
  end

  -- test_whisper_from_guildmate_on_battle_net_marks_bnet_first
  do
    local w = World.New()
    w.guildMembers["Arthas"] = true
    w.bnetByGuid["Player-1-AAA"] = {}
    local rel = Relationship.Resolve(w.item("Player-1-AAA", "Arthas"), w.runtime)
    assert(tiesOf(rel) == "bnet,guild" and rel.primary == "bnet", "bnet wins over guild, got " .. tiesOf(rel))
  end

  -- test_bnet_chat_with_guildmate_in_wow_marks_bnet_then_guild
  do
    local w = World.New()
    w.setBNet(7, { characterName = "Frodo", playerGuid = "Player-1-BNF" })
    w.guildMembers["Frodo"] = true
    local rel = Relationship.Resolve(w.bnItem(7), w.runtime)
    assert(tiesOf(rel) == "bnet,guild" and rel.primary == "bnet", "BNet chat in guild, got " .. tiesOf(rel))
  end

  -- test_bnet_chat_with_friend_offline_marks_bnet_only
  do
    local w = World.New()
    w.guildMembers["Frodo"] = true
    w.setBNet(7, { characterName = "", playerGuid = "Player-1-BNF" })
    local rel = Relationship.Resolve(w.bnItem(7), w.runtime)
    assert(tiesOf(rel) == "bnet" and rel.primary == "bnet", "offline BNet friend, got " .. tiesOf(rel))
    assert(w.calls.guild == 0 and w.playerInfoCalls == 0, "offline BNet chat calls no tie API")
  end

  -- test_no_ties_returns_nil
  do
    local w = World.New()
    assert(Relationship.Resolve(w.item("Player-1-AAA", "Arthas"), w.runtime) == nil, "no tie -> nil")
  end

  -- AC 2: a BNet friend's alt whispering shows bnet; the BNet chat shows bnet, then guild/community
  do
    local w = World.New()
    w.bnetByGuid["Player-1-ALT"] = { bnetAccountID = 7 }
    assert(tiesOf(Relationship.Resolve(w.item("Player-1-ALT", "Frodoalt"), w.runtime)) == "bnet", "alt whisper shows the bnet mark")

    w = World.New()
    w.setBNet(7, { characterName = "Frodo", playerGuid = "Player-1-BNF", realmName = "Area52" })
    w.bnetByGuid["Player-1-BNF"] = {}
    w.friendGuids["Player-1-BNF"] = true
    w.guildMembers["Frodo"] = true
    w.setCommunity("Player-1-BNF", 5, "Trade Hall")
    local before = { w.calls.bnetGuid, w.calls.isFriend, w.calls.friendInfo }
    local rel = Relationship.Resolve(w.bnItem(7), w.runtime)
    assert(tiesOf(rel) == "bnet,guild,community", "BNet chat: bnet then guild/community, got " .. tiesOf(rel))
    assert(w.calls.bnetGuid == before[1] and w.calls.isFriend == before[2] and w.calls.friendInfo == before[3], "BNet chat must not ask bnet/friend")
    -- name never carries the realm
    assert(w.lastGuildName == "Frodo", "BNet-chat name must not include realmName, got " .. tostring(w.lastGuildName))
  end

  -- BNet chat: not in WoW, no playerGuid, throwing lookup -> bnet only; group channel -> nil
  do
    local w = World.New()
    w.guildMembers["Frodo"] = true
    w.setBNet(7, { characterName = "", playerGuid = "Player-1-BNF" })
    assert(tiesOf(Relationship.Resolve(w.bnItem(7), w.runtime)) == "bnet", "BNet friend not in WoW -> bnet only")
    w.setBNet(8, { characterName = "Frodo" })
    assert(tiesOf(Relationship.Resolve(w.bnItem(8), w.runtime)) == "bnet", "no playerGuid -> bnet only")
    assert(w.nilArgs == 0 and w.calls.guild == 0, "no tie API for a BNet chat without playerGuid")
    assert(
      Relationship.Resolve({ conversationKey = "g", channel = "GUILD", guid = "Player-1-AAA", displayName = "Arthas" }, w.runtime) == nil,
      "group -> nil"
    )
    assert(w.calls.guild == 0, "group conversation calls no tie API")
    w.runtime.bnetApi.GetAccountInfoByID = function()
      error("bnet api failed")
    end
    local ok, rel = pcall(Relationship.Resolve, w.bnItem(9), w.runtime)
    assert(ok and tiesOf(rel) == "bnet", "throwing account lookup -> bnet only, no error")
  end

  -- missing API table / missing function -> tie absent, no error
  do
    local w = World.New()
    rawset(_G, "C_GuildInfo", nil)
    rawset(_G, "C_FriendList", nil)
    rawset(_G, "C_Club", nil)
    w.runtime.bnetApi = nil
    assert(Relationship.Resolve(w.item("Player-1-AAA", "Arthas"), w.runtime) == nil, "all APIs missing -> nil")
    Relationship.Invalidate(w.runtime) -- the first "no tie" answer is cached
    rawset(_G, "C_GuildInfo", {})
    rawset(_G, "C_FriendList", {})
    w.runtime.bnetApi = {}
    assert(Relationship.Resolve(w.item("Player-1-AAA", "Arthas"), w.runtime) == nil, "functions missing -> nil")
  end

  -- throwing API: tie absent, others still found, result not cached
  do
    local w = World.New()
    w.guildThrows = true
    w.setCommunity("Player-1-AAA", 5, "Trade Hall")
    local item = w.item("Player-1-AAA", "Arthas")
    assert(tiesOf(Relationship.Resolve(item, w.runtime)) == "community", "other ties survive a throwing guild API")
    Relationship.Resolve(item, w.runtime)
    assert(w.calls.guild == 2, "unreliable result must not be cached, guild calls " .. w.calls.guild)
  end

  -- throwing friend-by-name lookup: result not cached
  do
    local w = World.New()
    w.friendThrows = true
    local item = w.item("Player-1-AAA", "Arthas")
    assert(Relationship.Resolve(item, w.runtime) == nil, "throwing friend lookup -> no tie")
    local first = w.calls.friendInfo
    Relationship.Resolve(item, w.runtime)
    assert(w.calls.friendInfo > first, "a throwing friend lookup must not be cached")
  end

  -- friend listed under the short name: the realm-qualified name falls back to it
  do
    local w = World.New()
    local savedAmbiguate = rawget(_G, "Ambiguate")
    rawset(_G, "Ambiguate", function(name)
      return (string.gsub(name, "%-.*$", ""))
    end)
    w.friendNames["Arthas"] = true
    local rel = Relationship.Resolve(w.item("Player-1-AAA", "Arthas-Lordaeron"), w.runtime)
    assert(tiesOf(rel) == "friend", "short-name friend entry found, got " .. tiesOf(rel))
    rawset(_G, "Ambiguate", savedAmbiguate)
  end

  -- secret value: tie absent, result not cached
  do
    local w = World.New()
    rawset(_G, "issecretvalue", function(v)
      return v == "SECRET"
    end)
    w.guildSecret = true
    local item = w.item("Player-1-AAA", "Arthas")
    assert(Relationship.Resolve(item, w.runtime) == nil, "secret guild answer -> absent")
    Relationship.Resolve(item, w.runtime)
    assert(w.calls.guild == 2, "secret result must not be cached")
  end

  -- Review Focus 1: item.guid == nil -> no tie API gets a nil argument, no error, no mark
  do
    local w = World.New()
    w.guildMembers["Arthas"] = true
    local ok, rel = pcall(Relationship.Resolve, w.item(nil, "Arthas"), w.runtime)
    assert(ok and rel == nil, "nil guid -> nil mark without error")
    assert(w.nilArgs == 0, "no tie API may receive nil, got " .. w.nilArgs)
    w.setBNet(7, { characterName = "Frodo", playerGuid = nil })
    ok, rel = pcall(Relationship.Resolve, w.bnItem(7), w.runtime)
    assert(ok and tiesOf(rel) == "bnet" and w.nilArgs == 0, "BNet chat with no playerGuid -> bnet only, no nil argument")
  end

  -- Review Focus 2: player in no guild
  do
    local w = World.New()
    w.guildName = nil
    assert(Relationship.Resolve(w.item("Player-1-AAA", "Arthas"), w.runtime) == nil, "no guild: MemberExistsByName false -> no tie")
    Relationship.Invalidate(w.runtime) -- the "no tie" answer above is cached
    w.guildThrows = true
    local ok, rel = pcall(Relationship.Resolve, w.item("Player-1-AAA", "Arthas"), w.runtime)
    assert(ok and rel == nil, "no guild: throwing API -> no tie, no error")
    w.guildThrows = false
    w.guildMembers["Arthas"] = true -- member but GetGuildInfo has no name yet
    rel = Relationship.Resolve(w.item("Player-1-AAA", "Arthas"), w.runtime)
    assert(rel.guildName == nil, "no guild name -> nil, never the string 'nil'")
    local lines = Relationship.TooltipLines(rel)
    assert(#lines == 1 and lines[1] == "Guild", "tooltip says plain Guild, got " .. tostring(lines[1]))
  end

  -- Review Focus 3: Forever names keep their space
  do
    local w = World.New()
    w.guildMembers["Gurkan Warbringer"] = true
    w.friendNames["Gurkan Warbringer"] = true
    local rel = Relationship.Resolve(w.item("Player-1-GUR", "Gurkan Warbringer"), w.runtime)
    assert(tiesOf(rel) == "guild,friend", "space name keeps both ties, got " .. tiesOf(rel))
    assert(w.lastGuildName == "Gurkan Warbringer", "guild check got " .. tostring(w.lastGuildName))
    assert(w.lastFriendName == "Gurkan Warbringer", "friend check got " .. tostring(w.lastFriendName))
  end

  -- test_guild_check_falls_back_to_the_bare_name (Forever: GUID realm is a server id)
  -- Ambiguate keeps a realm it does not treat as the player's own, so the
  -- fallback must not depend on it.
  do
    local w = World.New()
    local savedAmbiguate = rawget(_G, "Ambiguate")
    rawset(_G, "Ambiguate", function(name)
      return name
    end)
    local savedForever = FlavorCompat.isForever
    FlavorCompat.isForever = true
    w.playerInfo["Player-6942-00082F35"] = { name = "Istaren Kementaro", realm = "CAMWOWEU4Realm8PvP" }
    w.guildMembers["Istaren Kementaro"] = true
    local rel = Relationship.Resolve(w.item("Player-6942-00082F35", "Istaren Kementaro"), w.runtime)
    rawset(_G, "Ambiguate", savedAmbiguate)
    FlavorCompat.isForever = savedForever
    assert(tiesOf(rel) == "guild", "bare-name guildmate found, got " .. tiesOf(rel))
  end

  -- test_cross_realm_namesake_is_not_a_guildmate_outside_forever
  -- Retail: "Bob-Kazzak" is a different character from the own-realm guildmate "Bob".
  do
    local w = World.New()
    local savedForever = FlavorCompat.isForever
    FlavorCompat.isForever = false
    w.playerInfo["Player-99-BOB"] = { name = "Bob", realm = "Kazzak" }
    w.guildMembers["Bob"] = true
    local rel = Relationship.Resolve(w.item("Player-99-BOB", "Bob-Kazzak"), w.runtime)
    FlavorCompat.isForever = savedForever
    assert(not tiesOf(rel):find("guild"), "namesake gets no guild tie, got " .. tiesOf(rel))
  end

  -- test_ties_use_the_guid_name_over_the_display_name
  do
    local w = World.New()
    w.playerInfo["Player-1-AAA"] = { name = "Arthas", realm = "" }
    w.guildMembers["Arthas"] = true
    w.friendNames["Arthas"] = true
    local rel = Relationship.Resolve(w.item("Player-1-AAA", "Stalename"), w.runtime)
    assert(tiesOf(rel) == "guild,friend", "GUID name checked, got " .. tiesOf(rel))
  end

  print("  All Relationship resolve tests passed")
end
