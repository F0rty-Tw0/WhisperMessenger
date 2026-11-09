local PublicApiEnv = require("tests.helpers.public_api_env")

local function noop() end

local function each(settings, fn)
  local runtime, api = PublicApiEnv.Initialize(settings)
  local ok, err = pcall(fn, runtime, api)
  PublicApiEnv.Reset()
  if not ok then
    error(err, 0)
  end
end

local function functionKeys(t)
  local keys = {}
  for key, value in pairs(t) do
    if type(value) == "function" then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys)
  return keys
end

return function()
  -- test_shared_table_contract_is_pinned (keys and version a third party relies on)
  each({}, function(_, api)
    local expected = {
      "Block",
      "Connect",
      "GetLook",
      "GetUnreadCount",
      "HidePreview",
      "InsertLink",
      "IsAnimationEnabled",
      "IsBlocked",
      "IsCompactWindow",
      "IsPanelShown",
      "IsPreviewShown",
      "OpenConversation",
      "RefreshPanelBadge",
      "RegisterPanel",
      "SetContactInfo",
      "ShowPanel",
      "ShowPreview",
      "TogglePanel",
      "Unblock",
    }
    assert(api.version == 1)
    assert(table.concat(functionKeys(api), ",") == table.concat(expected, ","), table.concat(functionKeys(api), ","))
  end)

  -- test_connect_returns_handle_with_every_key_but_connect
  each({}, function(_, api)
    local handle = api.Connect("CraftAlert")
    assert(type(handle) == "table" and handle.version == 1)
    local keys = functionKeys(handle)
    assert(#keys == #functionKeys(api) - 1 and handle.Connect == nil)
    for _, key in ipairs(keys) do
      assert(type(api[key]) == "function", key)
    end
  end)

  -- test_same_name_same_handle_and_same_functions
  each({}, function(_, api)
    local first, second = api.Connect("CraftAlert"), api.Connect("CraftAlert")
    assert(first == second and first.IsAnimationEnabled == second.IsAnimationEnabled, "no new closure per call")
    assert(api.Connect("Other") ~= first)
  end)

  -- test_bad_names_return_nil_and_record_nothing
  each({}, function(runtime, api)
    for _, bad in ipairs({ "", "   ", 5, true, string.rep("a", 65), "a|b", "|cffff0000x|r" }) do
      assert(api.Connect(bad) == nil, tostring(bad))
    end
    assert(api.Connect() == nil and api.Connect({}) == nil)
    assert(#runtime.addonIntegrations.rows() == 0)
    assert(api.Connect(string.rep("a", 64)) ~= nil, "64 bytes is fine")
  end)

  -- test_connect_records_the_addon_allowed
  each({}, function(runtime, api)
    api.Connect("CraftAlert")
    assert(runtime.addonIntegrations.isAllowed("CraftAlert") == true)
    assert(runtime.accountState.addonIntegrations.CraftAlert.allowed == true)
  end)

  -- test_handle_call_runs_when_ticked_and_is_refused_when_unticked
  each({}, function(runtime, api)
    local handle = api.Connect("CraftAlert")
    assert(handle.RegisterPanel("ca", { title = "Alerts", onShow = noop }) == true)
    runtime.addonIntegrations.setAllowed("CraftAlert", false)
    assert(handle.Block("Jaina-Proudmoore") == false, "refused, nothing blocked")
    assert(handle.GetUnreadCount("Jaina-Proudmoore") == 0, "refused count is the integer 0")
    assert(handle.GetLook() == false, "refusal is false even for table-returning calls")
    assert(api.Connect("CraftAlert") == handle, "Connect is never refused")
    runtime.addonIntegrations.setAllowed("CraftAlert", true)
    assert(handle.Block("Jaina-Proudmoore") == true)
  end)

  -- test_shared_table_counts_as_other_addons_even_when_refused
  each({}, function(runtime, api)
    assert(api.IsAnimationEnabled() == true)
    assert(runtime.addonIntegrations.rows()[1].shared == true)
    runtime.addonIntegrations.setAllowed("", false)
    assert(api.Block("Jaina-Proudmoore") == false and api.GetUnreadCount("x") == 0)
    assert(runtime.addonIntegrations.rows()[1].seen == true)
  end)

  -- test_unticking_other_addons_never_refuses_a_handle
  each({}, function(runtime, api)
    local handle = api.Connect("CraftAlert")
    api.IsAnimationEnabled()
    runtime.addonIntegrations.setAllowed("", false)
    assert(handle.IsAnimationEnabled() == true)
  end)

  -- test_caller_is_set_during_a_call_and_restored_after
  each({}, function(runtime, api)
    local handle = api.Connect("CraftAlert")
    assert(runtime.apiCaller == nil)
    handle.RegisterPanel("ca", { title = "Alerts", onShow = noop })
    api.IsAnimationEnabled()
    assert(runtime.apiCaller == nil, "restored to nil after shared call")
  end)

  -- test_nested_call_restores_the_outer_caller
  each({}, function(runtime, api)
    local a, b = api.Connect("A"), api.Connect("B")
    local innerAfter
    runtime.isWindowVisible = function()
      b.IsAnimationEnabled()
      innerAfter = runtime.apiCaller
      return false
    end
    a.OpenConversation("Jaina-Proudmoore")
    assert(innerAfter == "A", "after B returns, A is the caller again, got " .. tostring(innerAfter))
    assert(runtime.apiCaller == nil)
  end)

  -- test_raising_inner_call_restores_caller_and_returns_refusal
  each({}, function(runtime, api)
    local handle = api.Connect("CraftAlert")
    local saved = runtime.accountState
    runtime.accountState = setmetatable({}, {
      __index = function()
        error("boom")
      end,
    })
    local result = handle.IsAnimationEnabled()
    runtime.accountState = saved
    assert(result == false, "a raising inner call returns the refusal value")
    assert(runtime.apiCaller == nil, "a stuck caller would mis-own every later claim")
    assert(handle.IsAnimationEnabled() == true)
  end)

  -- test_global_off_connect_still_returns_a_handle_whose_calls_are_refused
  each({ allowAddonIntegration = false }, function(runtime, api)
    local handle = api.Connect("CraftAlert")
    assert(type(handle) == "table" and handle.version == 1)
    for key, value in pairs(handle) do
      if type(value) == "function" then
        assert(value() == (key == "GetUnreadCount" and 0 or false), key)
      end
    end
    assert(runtime.integrationAllowedAtLoad == false)
    assert(runtime.addonIntegrations.rows()[1].name == "CraftAlert", "row still recorded")
    api.IsAnimationEnabled()
    assert(#runtime.addonIntegrations.rows() == 1, "a shared-table call records nothing when global is off")
  end)

  -- test_build_works_on_a_bare_runtime
  do
    local PublicApi = require("WhisperMessenger.Core.PublicApi")
    local api = PublicApi.Build({})
    assert(api.Connect("X").IsAnimationEnabled() == true)
  end

  -- test_corrupt_saved_rows_do_not_make_the_api_throw
  do
    local PublicApi = require("WhisperMessenger.Core.PublicApi")
    local api = PublicApi.Build({ accountState = { addonIntegrations = { [""] = 5, CraftAlert = true } } })
    assert(api.IsAnimationEnabled() == true)
    assert(api.Connect("CraftAlert").IsAnimationEnabled() == true)
  end

  -- test_registry_that_raises_makes_every_call_a_refusal_not_an_error
  do
    local PublicApi = require("WhisperMessenger.Core.PublicApi")
    local armed = false
    local backing = { addonIntegrations = {} }
    local account = setmetatable({}, {
      __index = function(_, key)
        if armed then
          error("boom " .. tostring(key))
        end
        return backing[key]
      end,
    })
    local api = PublicApi.Build({ accountState = account })
    local handle = api.Connect("CraftAlert")
    armed = true
    local ok, err = pcall(function()
      assert(api.IsAnimationEnabled() == false and api.GetUnreadCount("x") == 0, "shared call refused")
      assert(handle.IsAnimationEnabled() == false and handle.GetUnreadCount("x") == 0, "handle call refused")
    end)
    armed = false
    assert(ok, err)
  end

  -- test_raising_allow_check_refuses_even_when_the_call_itself_works
  do
    local PublicApi = require("WhisperMessenger.Core.PublicApi")
    local runtime = { accountState = { addonIntegrations = {} } }
    local api = PublicApi.Build(runtime)
    local handle = api.Connect("CraftAlert")
    assert(handle.IsAnimationEnabled() == true, "the raw call answers true")
    runtime.addonIntegrations.isAllowed = function()
      error("boom")
    end
    assert(api.IsAnimationEnabled() == false, "shared call fails closed")
    assert(handle.IsAnimationEnabled() == false, "handle call fails closed")
  end
end
