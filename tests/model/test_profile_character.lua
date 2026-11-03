local ProfileCharacter = require("WhisperMessenger.Model.ProfileCharacter")

-- Which WoW character a contact row stands for, for profile links.

local OWN = { display = "Argent Dawn", normalized = "ArgentDawn" }

return function()
  -- test_cross_realm_whisper_splits_name_and_realm
  do
    local character = ProfileCharacter.FromItem({ channel = "WOW", displayName = "Arthas-Area52" }, OWN)
    assert(character.name == "Arthas" and character.realm == "Area52", "name and realm split")
    assert(character.displayRealm == nil, "another realm's display name is unknown")
  end

  -- test_same_realm_whisper_uses_own_realm
  do
    local character = ProfileCharacter.FromItem({ channel = "WOW", displayName = "Jaina" }, OWN)
    assert(character.name == "Jaina" and character.realm == "ArgentDawn", "own realm filled in")
    assert(character.displayRealm == "Argent Dawn", "own realm display name known")
  end

  -- test_own_realm_suffix_gets_display_name
  do
    local character = ProfileCharacter.FromItem({ channel = "WOW", displayName = "Jaina-ArgentDawn" }, OWN)
    assert(character.displayRealm == "Argent Dawn", "own realm suffix maps to its display name")
  end

  -- test_battlenet_friend_uses_known_character
  do
    local character = ProfileCharacter.FromItem({ channel = "BN", displayName = "Friend#1234", gameAccountName = "Thrall-Area52" }, OWN)
    assert(character ~= nil and character.name == "Thrall" and character.realm == "Area52", "BN friend's character used")
  end

  -- test_battlenet_friend_enriched_character_wins
  do
    local character = ProfileCharacter.FromItem({
      channel = "BN",
      gameAccountName = "Thrall-Area52",
      characterName = "Garrosh",
      realm = "Area 52",
    }, OWN)
    assert(character.name == "Garrosh", "live character used")
    assert(character.displayRealm == "Area 52", "a realm with a space is a display name")
  end

  -- test_battlenet_friend_without_character_has_none
  do
    assert(ProfileCharacter.FromItem({ channel = "BN", displayName = "Friend#1234" }, OWN) == nil, "no WoW character known")
  end

  -- test_battlenet_friend_without_realm_has_none
  do
    assert(ProfileCharacter.FromItem({ channel = "BN", gameAccountName = "Thrall" }, OWN) == nil, "realm unknown")
  end

  -- test_group_rows_have_none
  do
    assert(ProfileCharacter.FromItem({ channel = "GUILD", displayName = "Guild" }, OWN) == nil, "group rows are not a character")
  end

  -- test_protected_battlenet_name_has_none
  do
    assert(ProfileCharacter.FromItem({ channel = "WOW", displayName = "|Kq1|k" }, OWN) == nil, "protected names have none")
  end

  -- test_secret_name_has_none
  do
    local secret = "Arthas-Area52"
    local savedIsSecret = _G.issecretvalue
    rawset(_G, "issecretvalue", function(value)
      return value == secret
    end)
    local character = ProfileCharacter.FromItem({ channel = "WOW", displayName = secret }, OWN)
    rawset(_G, "issecretvalue", savedIsSecret)
    assert(character == nil, "a chat-lockdown secret name is never read")
  end

  -- test_same_realm_without_own_realm_has_none
  do
    assert(ProfileCharacter.FromItem({ channel = "WOW", displayName = "Jaina" }, {}) == nil, "own realm unknown")
  end
end
