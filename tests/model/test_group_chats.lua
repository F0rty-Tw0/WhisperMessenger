local GroupChats = require("WhisperMessenger.Model.GroupChats")

local function sequence(values)
  local index = 0
  return function()
    index = index + 1
    return values[(index - 1) % #values + 1]
  end
end

return function()
  -- test_new_id_is_eight_lowercase_alphanumerics
  do
    local id = GroupChats.NewId(sequence({ 1, 26, 27, 36 }))
    assert(id == "az09az09", "unexpected id " .. tostring(id))
    assert(GroupChats.IsValidId(id), "a new id must be valid")
    assert(not GroupChats.IsValidId("ABCDEFGH"), "uppercase ids are invalid")
    assert(not GroupChats.IsValidId("abc"), "short ids are invalid")
  end

  -- test_conversation_key_round_trips_the_id
  do
    local key = GroupChats.ConversationKey("abcd1234")
    assert(key == "wmgroup::abcd1234", key)
    assert(GroupChats.IdFromConversationKey(key) == "abcd1234", "id should come back from the key")
    assert(GroupChats.IdFromConversationKey("party::me") == nil, "other keys carry no group id")
    assert(GroupChats.IdFromConversationKey("wmgroup::bad") == nil, "malformed ids are rejected")
  end

  -- test_full_name_drops_the_local_realm
  do
    assert(GroupChats.FullName("Anna", "Kazzak") == "Anna", "a bare name stays bare")
    assert(GroupChats.FullName("Anna-Kazzak", "Kazzak") == "Anna", "the local realm goes")
    assert(GroupChats.FullName("anna-KAZZAK", "Kazzak") == "anna", "realms compare without case")
    assert(GroupChats.FullName(" Bela-Argent Dawn ", "Kazzak") == "Bela-ArgentDawn", "other realms stay, without spaces")
    assert(GroupChats.FullName("", "Kazzak") == nil)
    assert(GroupChats.FullName("bad|name", "Kazzak") == nil, "escape codes are not names")
    assert(GroupChats.FullName("-Kazzak", "Kazzak") == nil, "a realm alone is not a name")
    assert(GroupChats.FullName("Anna-", "Kazzak") == nil, "a dangling hyphen is not a name")
  end

  -- test_full_name_keeps_two_word_names
  do
    assert(GroupChats.FullName("Lone  Gazer", "CAMWOWEU5Realm2PvP") == "Lone Gazer", "WoW: Forever names keep their space")
    assert(GroupChats.FullName("Lone Gazer-CAMWOWEU5Realm2PvP", "CAMWOWEU5Realm2PvP") == "Lone Gazer")
    assert(GroupChats.FullName("Lone Gazer-Other Realm", "CAMWOWEU5Realm2PvP") == "Lone Gazer-OtherRealm")
  end

  -- test_qualify_adds_the_local_realm_for_the_wire
  do
    assert(GroupChats.Qualify("Lone Gazer", "Kazzak") == "Lone Gazer-Kazzak")
    assert(GroupChats.Qualify("Bela-Ragnaros", "Kazzak") == "Bela-Ragnaros", "a realm already there stays")
    assert(GroupChats.Qualify("Anna", nil) == "Anna", "no realm known, nothing added")
  end

  -- test_parse_names_dedupes_and_drops_self
  do
    local names = GroupChats.ParseNames("Anna, bela; ANNA-Kazzak, Me, Csilla-Ragnaros, Lone Gazer,,", "Kazzak", "Me")
    assert(#names == 4, "expected 4 names, got " .. #names)
    assert(names[1] == "Anna" and names[2] == "bela" and names[3] == "Csilla-Ragnaros" and names[4] == "Lone Gazer", table.concat(names, "|"))
  end

  -- test_clean_name_strips_separators_and_caps_length
  do
    assert(GroupChats.CleanName("  Raid~night|  ") == "Raidnight")
    assert(GroupChats.CleanName("   ") == nil)
    local long = string.rep("a", 40)
    assert(#GroupChats.CleanName(long) == GroupChats.MAX_NAME_CHARS, "names are capped")
    local accented = string.rep("é", 40)
    local capped = GroupChats.CleanName(accented)
    assert(#capped == GroupChats.MAX_NAME_CHARS * 2, "the cap counts characters, not bytes")
  end

  -- test_default_name_lists_short_member_names
  do
    assert(GroupChats.DefaultName({ "Anna-Kazzak", "Bela-Ragnaros" }) == "Anna, Bela")
  end

  -- test_create_names_the_group_after_its_members_when_unnamed
  do
    local registry = {}
    local group = GroupChats.Create(registry, { id = "abcd1234", members = { "Anna-Kazzak", "Me" }, createdAt = 5, selfName = "Me" })
    assert(registry.abcd1234 == group, "group is stored by id")
    assert(group.name == "Anna", "unnamed group takes its members' names, got " .. group.name)
    assert(#group.members == 1, "the local character is never a member of its own list")
    assert(group.createdAt == 5)
  end

  -- test_members_are_capped
  do
    local names = {}
    for index = 1, GroupChats.MAX_MEMBERS + 3 do
      names[index] = "P" .. index .. "-Kazzak"
    end
    local group = GroupChats.Create({}, { id = "abcd1234", name = "Big", members = names })
    assert(#group.members == GroupChats.MAX_MEMBERS, "member list must be capped")
    local added = GroupChats.AddMembers(group, { "Extra-Kazzak" })
    assert(#added == 0, "a full group takes nobody")
  end

  -- test_add_and_remove_members_are_case_insensitive
  do
    local group = GroupChats.Create({}, { id = "abcd1234", name = "G", members = { "Anna-Kazzak" } })
    local added = GroupChats.AddMembers(group, { "anna-kazzak", "Bela-Kazzak" }, "Me-Kazzak")
    assert(#added == 1 and added[1] == "Bela-Kazzak", "only the new member is added")
    assert(GroupChats.IsMember(group, "BELA-kazzak"), "membership ignores case")
    assert(GroupChats.RemoveMember(group, "ANNA-KAZZAK"), "remove ignores case")
    assert(not GroupChats.IsMember(group, "Anna-Kazzak"))
    assert(not GroupChats.RemoveMember(group, "Nobody-Kazzak"))
  end

  -- test_joined_skips_left_groups_and_sorts_by_creation
  do
    local registry = {}
    GroupChats.Create(registry, { id = "bbbbbbbb", name = "B", members = {}, createdAt = 20 })
    GroupChats.Create(registry, { id = "aaaaaaaa", name = "A", members = {}, createdAt = 10 })
    GroupChats.Create(registry, { id = "cccccccc", name = "C", members = {}, createdAt = 5 }).left = true
    local joined = GroupChats.Joined(registry)
    assert(#joined == 2 and joined[1].id == "aaaaaaaa" and joined[2].id == "bbbbbbbb", "joined groups, oldest first")
  end

  -- test_member_summary_lists_members
  do
    local group = { members = { "Anna", "Bela-Ragnaros" } }
    assert(GroupChats.MemberSummary(group) == "Anna, Bela-Ragnaros", GroupChats.MemberSummary(group))
  end

  -- test_ensure_creates_the_registry_once
  do
    local accountState = {}
    local registry = GroupChats.Ensure(accountState)
    assert(accountState.groupChats == registry and GroupChats.Ensure(accountState) == registry)
  end
end
