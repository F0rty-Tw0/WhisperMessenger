local PublicApiEnv = require("tests.helpers.public_api_env")
local Guards = require("WhisperMessenger.Core.PublicApi.Guards")

local function noop() end
local PREVIEW = { sender = "Jaina", text = "hi" }

local function each(fn)
  local runtime, api = PublicApiEnv.Initialize({})
  local ok, err = pcall(fn, runtime, api)
  PublicApiEnv.Reset()
  if not ok then
    error(err, 0)
  end
end

return function()
  -- test_panel_belongs_to_the_handle_that_registered_it
  each(function(runtime, api)
    local handle = api.Connect("CraftAlert")
    assert(handle.RegisterPanel("ca", { title = "Alerts", onShow = noop }) == true)
    assert(runtime.addonIntegrations.ownerOf("panel", "ca") == "CraftAlert")
  end)

  -- test_shared_table_panel_belongs_to_other_addons
  each(function(runtime, api)
    assert(api.RegisterPanel("x", { title = "X", onShow = noop }) == true)
    assert(runtime.addonIntegrations.ownerOf("panel", "x") == "")
  end)

  -- test_second_registration_of_a_key_fails_and_owner_stays
  each(function(runtime, api)
    api.Connect("A").RegisterPanel("k", { title = "K", onShow = noop })
    assert(api.Connect("B").RegisterPanel("k", { title = "K2", onShow = noop }) == false)
    assert(runtime.addonIntegrations.ownerOf("panel", "k") == "A")
  end)

  -- test_invalid_panel_claims_nothing
  each(function(runtime, api)
    assert(api.Connect("A").RegisterPanel("k", { title = "" }) == false)
    assert(runtime.addonIntegrations.ownerOf("panel", "k") == nil)
  end)

  -- test_preview_owner_moves_with_the_latest_show
  each(function(runtime, api)
    runtime.getWidgetIcon = function()
      return {
        isRiding = function()
          return false
        end,
      }
    end
    local a, b = api.Connect("A"), api.Connect("B")
    assert(a.ShowPreview("slot", PREVIEW) == true)
    assert(runtime.addonIntegrations.ownerOf("preview", "slot") == "A")
    assert(b.ShowPreview("slot", PREVIEW) == true)
    assert(runtime.addonIntegrations.ownerOf("preview", "slot") == "B")
  end)

  -- test_note_belongs_to_the_latest_setter
  each(function(runtime, api)
    assert(api.Connect("A").SetContactInfo("src", "Jaina-Proudmoore", "x") == true)
    assert(runtime.addonIntegrations.ownerOf("note", "src") == "A")
    assert(api.Connect("B").SetContactInfo("src", "Jaina-Proudmoore", "y") == true)
    assert(runtime.addonIntegrations.ownerOf("note", "src") == "B")
  end)

  -- test_internal_path_without_a_caller_owns_nothing
  each(function(runtime)
    assert(runtime.apiCaller == nil)
    Guards.Claim(runtime, "panel", "internal")
    assert(runtime.addonIntegrations.ownerOf("panel", "internal") == nil)
    runtime.panelRegistry.register("wm", { title = "WM", onShow = noop })
    assert(runtime.addonIntegrations.ownerOf("panel", "wm") == nil)
  end)

  -- test_claim_without_a_registry_is_a_no_op
  do
    Guards.Claim({ apiCaller = "A" }, "panel", "k")
  end
end
