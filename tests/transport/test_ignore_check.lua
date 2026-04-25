local IgnoreCheck = require("WhisperMessenger.Transport.IgnoreCheck")

return function()
  -- Test 1: nil/non-table api returns false
  assert(IgnoreCheck.IsContactIgnored(nil, "Thrall", "guid-1") == false)
  assert(IgnoreCheck.IsContactIgnored("not a table", "Thrall", "guid-1") == false)

  -- Test 2: GUID match returns true
  do
    local api = {
      IsIgnoredByGuid = function(guid)
        return guid == "guid-block"
      end,
    }
    assert(IgnoreCheck.IsContactIgnored(api, "Thrall", "guid-block") == true)
    assert(IgnoreCheck.IsContactIgnored(api, "Thrall", "guid-other") == false)
  end

  -- Test 3: Name match returns true when GUID lookup misses
  do
    local seen = {}
    local api = {
      IsIgnoredByGuid = function(guid)
        table.insert(seen, "guid:" .. tostring(guid))
        return false
      end,
      IsIgnored = function(name)
        table.insert(seen, "name:" .. tostring(name))
        return name == "Thrall"
      end,
    }
    assert(IgnoreCheck.IsContactIgnored(api, "Thrall", "guid-x") == true)
    assert(seen[1] == "guid:guid-x", "expected GUID lookup first, got: " .. tostring(seen[1]))
    assert(seen[2] == "name:Thrall", "expected name lookup second, got: " .. tostring(seen[2]))
  end

  -- Test 4: empty/nil name skips IsIgnored call
  do
    local nameCalled = false
    local api = {
      IsIgnored = function()
        nameCalled = true
        return true
      end,
    }
    assert(IgnoreCheck.IsContactIgnored(api, "", nil) == false)
    assert(IgnoreCheck.IsContactIgnored(api, nil, nil) == false)
    assert(nameCalled == false, "IsIgnored must not be called with empty/nil name")
  end

  -- Test 5: pcall guards against API errors (returns false rather than crashing)
  do
    local api = {
      IsIgnoredByGuid = function()
        error("boom")
      end,
      IsIgnored = function()
        error("boom")
      end,
    }
    assert(IgnoreCheck.IsContactIgnored(api, "Thrall", "guid-x") == false)
  end

  -- Test 6: missing IsIgnoredByGuid still falls back to IsIgnored
  do
    local api = {
      IsIgnored = function(name)
        return name == "Sylvanas"
      end,
    }
    assert(IgnoreCheck.IsContactIgnored(api, "Sylvanas", "guid-y") == true)
    assert(IgnoreCheck.IsContactIgnored(api, "Thrall", "guid-y") == false)
  end
end
