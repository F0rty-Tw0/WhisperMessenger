local Theme = require("WhisperMessenger.UI.Theme")

return function()
  -- test_every_tie_has_its_own_texture_path
  local seen = {}
  for _, tie in ipairs({ "guild", "bnet", "friend", "community" }) do
    local path = Theme.TEXTURES["relationship_" .. tie]
    assert(type(path) == "string" and path ~= "", tie .. ": texture path set")
    assert(not seen[path], tie .. ": path differs from the other ties, got " .. path)
    seen[path] = true
  end

  -- test_each_tie_uses_the_picked_art
  local expected = {
    guild = "Interface\\ICONS\\INV_Shield_06",
    bnet = "Interface\\FriendsFrame\\Battlenet-Portrait",
    friend = "Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon",
    community = "Interface\\ICONS\\Achievement_GuildPerk_EverybodysFriend",
  }
  for tie, path in pairs(expected) do
    local got = Theme.TEXTURES["relationship_" .. tie]
    assert(got == path, tie .. ": expected " .. path .. ", got " .. tostring(got))
  end

  -- test_only_guild_has_an_atlas
  assert(Theme.RelationshipAtlas("guild") == "communities-guildbanner-background", "guild atlas")
  for _, tie in ipairs({ "bnet", "friend", "community", "nope" }) do
    assert(Theme.RelationshipAtlas(tie) == nil, tie .. ": no atlas")
  end

  -- test_guild_shield_is_tinted_green_and_the_rest_are_not
  local tint = Theme.RelationshipTint("guild")
  assert(tint and tint[2] > tint[1] and tint[2] > tint[3], "guild tint is green")
  for _, tie in ipairs({ "bnet", "friend", "community", "nope" }) do
    assert(Theme.RelationshipTint(tie) == nil, tie .. ": no tint")
  end

  -- test_sizes_match_the_spec
  assert(Theme.LAYOUT.CONTACT_RELATIONSHIP_SIZE == 14, "row mark is 14 px")
  assert(Theme.LAYOUT.CONTACT_RELATIONSHIP_SIZE == Theme.LAYOUT.CONTACT_FACTION_SIZE, "same size as the faction icon")
  assert(Theme.LAYOUT.HEADER_RELATIONSHIP_SIZE == 16, "header mark is 16 px")
end
