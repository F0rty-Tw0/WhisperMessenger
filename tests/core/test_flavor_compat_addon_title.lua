local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")

local function withGlobals(set, fn)
  local saved = { C_AddOns = _G.C_AddOns, GetAddOnInfo = _G.GetAddOnInfo }
  _G.C_AddOns, _G.GetAddOnInfo = set.C_AddOns, set.GetAddOnInfo
  local ok, err = pcall(fn)
  _G.C_AddOns, _G.GetAddOnInfo = saved.C_AddOns, saved.GetAddOnInfo
  if not ok then
    error(err, 0)
  end
end

return function()
  -- test_namespaced_call_gives_the_title
  withGlobals({
    C_AddOns = {
      GetAddOnInfo = function(n)
        return n, "Craft Alert", "notes", true
      end,
    },
  }, function()
    assert(FlavorCompat.GetAddOnTitle("CraftAlert") == "Craft Alert")
  end)

  -- test_global_call_is_the_fallback
  withGlobals({
    GetAddOnInfo = function(n)
      return n, "Old Title", "", true
    end,
  }, function()
    assert(FlavorCompat.GetAddOnTitle("X") == "Old Title")
  end)

  -- test_namespaced_call_wins_over_global
  withGlobals({
    C_AddOns = {
      GetAddOnInfo = function(n)
        return n, "New", "", true
      end,
    },
    GetAddOnInfo = function(n)
      return n, "Old", "", true
    end,
  }, function()
    assert(FlavorCompat.GetAddOnTitle("X") == "New")
  end)

  -- test_missing_addon_gives_nil_even_when_the_call_echoes_the_name
  withGlobals({
    GetAddOnInfo = function(n)
      return n, n, nil, false, "MISSING"
    end,
  }, function()
    assert(FlavorCompat.GetAddOnTitle("NoSuch") == nil)
  end)

  -- test_blank_or_missing_title_gives_nil
  withGlobals({
    GetAddOnInfo = function(n)
      return n, "   "
    end,
  }, function()
    assert(FlavorCompat.GetAddOnTitle("X") == nil)
  end)
  withGlobals({
    GetAddOnInfo = function(n)
      return n
    end,
  }, function()
    assert(FlavorCompat.GetAddOnTitle("X") == nil)
  end)

  -- test_raising_call_gives_nil
  withGlobals({
    GetAddOnInfo = function()
      error("boom")
    end,
  }, function()
    assert(FlavorCompat.GetAddOnTitle("X") == nil)
  end)

  -- test_no_api_or_bad_name_gives_nil
  withGlobals({}, function()
    assert(FlavorCompat.GetAddOnTitle("X") == nil)
  end)
  withGlobals({
    GetAddOnInfo = function(n)
      return n, "T"
    end,
  }, function()
    assert(FlavorCompat.GetAddOnTitle("") == nil and FlavorCompat.GetAddOnTitle(5) == nil)
  end)
end
