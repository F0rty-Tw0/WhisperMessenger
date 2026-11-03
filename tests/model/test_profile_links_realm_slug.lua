local ProfileLinks = require("WhisperMessenger.Model.ProfileLinks")

-- Realm part of a profile URL. A display name ("Area 52") gives the exact
-- site slug; a chat realm ("Area52", spaces dropped) gives a bare slug that
-- Raider.IO and Warcraft Logs accept but the Armory doesn't. Site slugs are
-- plain ASCII: accents fold away, other scripts give no slug.

local function slugOf(character)
  local slug, exact = ProfileLinks.RealmSlug(character)
  return slug, exact
end

return function()
  -- test_display_realm_spaces_become_dashes
  do
    local slug, exact = slugOf({ realm = "Area52", displayRealm = "Area 52" })
    assert(slug == "area-52" and exact == true, "Area 52 -> area-52, got " .. tostring(slug))
  end

  -- test_display_realm_drops_hyphens_and_apostrophes
  do
    assert(slugOf({ displayRealm = "Azjol-Nerub" }) == "azjolnerub", "Azjol-Nerub -> azjolnerub")
    assert(slugOf({ displayRealm = "Mal'Ganis" }) == "malganis", "Mal'Ganis -> malganis")
  end

  -- test_display_realm_drops_brackets_and_folds_accents
  do
    local slug = slugOf({ displayRealm = "Aggra (Português)" })
    assert(slug == "aggra-portugues", "Aggra (Português) slug, got " .. tostring(slug))
  end

  -- test_display_realm_folds_lowercase_accents
  do
    local slug = slugOf({ displayRealm = "Chants éternels" })
    assert(slug == "chants-eternels", "Chants éternels slug, got " .. tostring(slug))
  end

  -- test_display_realm_folds_uppercase_accents_and_sharp_s
  do
    local slug = slugOf({ displayRealm = "ÀÁÂÄÃÅ ÈÉÊË ÌÍÎÏ ÒÓÔÖÕ ÙÚÛÜ Ç Ñ ß" })
    assert(slug == "aaaaaa-eeee-iiii-ooooo-uuuu-c-n-ss", "uppercase folds, got " .. tostring(slug))
  end

  -- test_non_latin_display_realm_has_no_slug
  do
    assert(slugOf({ realm = "Гордунни", displayRealm = "Гордунни" }) == nil, "Cyrillic realm has no slug")
  end

  -- test_non_latin_chat_realm_has_no_slug
  do
    assert(slugOf({ realm = "아즈샤라" }) == nil, "Korean chat realm has no slug")
  end

  -- test_chat_realm_gives_bare_lowercase_slug
  do
    local slug, exact = slugOf({ realm = "Twilight'sHammer" })
    assert(slug == "twilightshammer", "bare slug, got " .. tostring(slug))
    assert(exact == false, "a multi-word chat realm is not an exact slug")
  end

  -- test_one_word_chat_realm_is_exact
  do
    local slug, exact = slugOf({ realm = "Kazzak" })
    assert(slug == "kazzak" and exact == true, "one-word realm is exact, got " .. tostring(slug))
  end

  -- test_missing_realm_gives_nil
  do
    assert(slugOf({ name = "Arthas" }) == nil, "no realm, no slug")
  end
end
