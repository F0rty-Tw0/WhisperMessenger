local ProfileLinks = require("WhisperMessenger.Model.ProfileLinks")

-- Realm part of a profile URL. A display name ("Area 52") gives the exact
-- site slug; a chat realm ("Area52", spaces dropped) gives a bare slug that
-- Raider.IO and Warcraft Logs accept but the Armory doesn't.

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

  -- test_display_realm_drops_brackets_and_encodes_accents
  do
    local slug = slugOf({ displayRealm = "Aggra (Português)" })
    assert(slug == "aggra-portugu%C3%AAs", "Aggra (Português) slug, got " .. tostring(slug))
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
