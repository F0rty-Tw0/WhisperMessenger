local LocalPlayer = require("WhisperMessenger.Core.LocalPlayer")

return function()
  local savedName, savedClass = _G.UnitName, _G.UnitClass

  -- test_reads_name_and_class_tag
  rawset(_G, "UnitName", function()
    return "Arthas"
  end)
  rawset(_G, "UnitClass", function()
    return "Paladin", "PALADIN"
  end)
  assert(LocalPlayer.Name() == "Arthas", "name")
  assert(LocalPlayer.ClassTag() == "PALADIN", "class tag")

  -- test_blank_values_read_as_nil
  rawset(_G, "UnitName", function()
    return ""
  end)
  rawset(_G, "UnitClass", function()
    return "Paladin", ""
  end)
  assert(LocalPlayer.Name() == nil and LocalPlayer.ClassTag() == nil, "blank values are nil")

  -- test_throwing_api_reads_as_nil
  rawset(_G, "UnitName", function()
    error("secret")
  end)
  assert(LocalPlayer.Name() == nil, "throwing API is nil")

  -- test_missing_api_reads_as_nil
  rawset(_G, "UnitName", nil)
  rawset(_G, "UnitClass", nil)
  assert(LocalPlayer.Name() == nil and LocalPlayer.ClassTag() == nil, "missing API is nil")

  -- test_normalized_realm_reads_live_and_tolerates_bad_api
  local savedRealm = _G.GetNormalizedRealmName
  rawset(_G, "GetNormalizedRealmName", function()
    return "Area52"
  end)
  assert(LocalPlayer.NormalizedRealm() == "Area52", "realm")
  rawset(_G, "GetNormalizedRealmName", function()
    error("secret")
  end)
  assert(LocalPlayer.NormalizedRealm() == nil, "throwing realm API is nil")
  rawset(_G, "GetNormalizedRealmName", nil)
  assert(LocalPlayer.NormalizedRealm() == nil, "missing realm API is nil")

  -- test_secret_values_read_as_nil
  local savedSecret = _G.issecretvalue
  rawset(_G, "UnitName", function()
    return "Arthas"
  end)
  rawset(_G, "issecretvalue", function(value)
    return value == "Arthas"
  end)
  assert(LocalPlayer.Name() == nil, "a secret name is nil, never compared")
  rawset(_G, "issecretvalue", savedSecret)

  local savedGuid = _G.UnitGUID
  rawset(_G, "UnitName", function()
    return "Me"
  end)
  rawset(_G, "GetNormalizedRealmName", function()
    return "Area52"
  end)
  rawset(_G, "UnitGUID", function()
    return "Player-1-SELF"
  end)

  -- test_is_self_by_guid
  assert(LocalPlayer.IsSelf("Someone", "Player-1-SELF") == true, "own guid is self")

  -- test_is_self_by_short_name
  assert(LocalPlayer.IsSelf("Me", nil) == true, "own short name is self")

  -- test_is_self_by_name_realm
  assert(LocalPlayer.IsSelf("Me-Area52", nil) == true, "own name-realm is self")

  -- test_is_self_false_for_other_player
  assert(LocalPlayer.IsSelf("Arthas-Area52", "Player-1-OTHER") == false, "other player is not self")

  -- test_is_self_secret_guid_compare_throws
  do
    local secretMeta = {
      __eq = function()
        error("secret compare")
      end,
    }
    rawset(_G, "UnitGUID", function()
      return setmetatable({}, secretMeta)
    end)
    local ok, result = pcall(LocalPlayer.IsSelf, "Arthas", setmetatable({}, secretMeta))
    assert(ok and result == false, "a throwing guid compare is not self and does not throw")
  end

  -- test_is_self_without_guid_is_not_self_when_own_guid_is_nil
  rawset(_G, "UnitGUID", function()
    return nil
  end)
  assert(LocalPlayer.IsSelf("Arthas-Area52", nil) == false, "two missing guids do not make a match")

  -- test_is_self_without_realm_matches_short_name_only
  rawset(_G, "GetNormalizedRealmName", function()
    return nil
  end)
  do
    local ok, result = pcall(LocalPlayer.IsSelf, "Me-Area52", nil)
    assert(ok and result == false, "no realm: a name-realm is not self and does not throw")
  end
  assert(LocalPlayer.IsSelf("Me", nil) == true, "no realm: own short name is still self")

  rawset(_G, "UnitGUID", savedGuid)
  rawset(_G, "UnitName", savedName)
  rawset(_G, "UnitClass", savedClass)
  rawset(_G, "GetNormalizedRealmName", savedRealm)
end
