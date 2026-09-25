local Identity = require("WhisperMessenger.Model.Identity")

-- One secret-safe Ambiguate(name, "none") for every caller.
return function()
  local saved = _G.Ambiguate

  -- test_short_name_strips_the_same_realm_suffix
  rawset(_G, "Ambiguate", function(name)
    return (string.gsub(name, "%-Home$", ""))
  end)
  assert(Identity.ShortName("Thrall-Home") == "Thrall", "same-realm suffix dropped")
  assert(Identity.ShortName("Jaina-Away") == "Jaina-Away", "other realm kept")

  -- test_short_name_falls_back_when_ambiguate_rejects_the_value
  rawset(_G, "Ambiguate", function()
    error("secret value")
  end)
  assert(Identity.ShortName("Thrall-Home") == "Thrall-Home", "name unchanged when Ambiguate throws")

  -- test_short_name_without_the_api
  rawset(_G, "Ambiguate", nil)
  assert(Identity.ShortName("Thrall-Home") == "Thrall-Home", "name unchanged without Ambiguate")

  rawset(_G, "Ambiguate", saved)
end
