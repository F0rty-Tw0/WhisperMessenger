local AddonIntegrations = require("WhisperMessenger.Model.AddonIntegrations")
local ContactInfo = require("WhisperMessenger.Model.ContactInfo")
local ExternalPreview = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ExternalPreview")
local IntegrationAccess = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IntegrationAccess")
local PublicApiEnv = require("tests.helpers.public_api_env")
local withPopups = require("tests.helpers.reload_popups").With

local function makeRuntime(saved, opts)
  opts = opts or {}
  local calls = {}
  local runtime = {
    addonIntegrations = AddonIntegrations.New({ addonIntegrations = saved }, function()
      return nil
    end),
    contactInfo = ContactInfo.New(),
    externalPreview = ExternalPreview.New({
      now = function()
        return 1
      end,
    }),
    panelRegistry = {
      applyActive = function(key)
        calls[#calls + 1] = "apply:" .. key
      end,
    },
    updateIconSurfaces = function()
      calls[#calls + 1] = "icons"
    end,
    refreshWindow = function()
      calls[#calls + 1] = "refresh"
    end,
    isWindowVisible = function()
      return opts.visible == true
    end,
    window = {
      getVisiblePanel = function()
        return opts.openPanel
      end,
      hidePanel = function()
        calls[#calls + 1] = "hidePanel"
        if opts.hideRaises then
          error("boom")
        end
      end,
      refreshPanelBadge = function(key)
        calls[#calls + 1] = "badge:" .. key
        if opts.badgeRaises then
          error("boom")
        end
      end,
    },
  }
  IntegrationAccess.Attach(runtime)
  return runtime, calls
end

return function()
  -- test_refusing_hides_tab_clears_preview_and_notes_the_addon_owns
  do
    local runtime, calls = makeRuntime(nil, { visible = true, openPanel = "ca" })
    local reg = runtime.addonIntegrations
    reg.touch("CraftAlert")
    reg.claim("panel", "ca", "CraftAlert")
    reg.claim("preview", "pv", "CraftAlert")
    reg.claim("note", "src", "CraftAlert")
    runtime.externalPreview.set("pv", { sender = "x", text = "y" })
    ContactInfo.Set(runtime.contactInfo, "src", "Arthas", "note")
    ContactInfo.Set(runtime.contactInfo, "unowned", "Arthas", "keep")
    reg.setAllowed("CraftAlert", false)
    assert(calls[1] == "hidePanel", "open panel closed first, got " .. tostring(calls[1]))
    assert(calls[2] == "apply:ca", "tab hidden, got " .. tostring(calls[2]))
    assert(runtime.externalPreview.get() == nil, "its preview is cleared")
    assert(runtime.contactInfo["arthas"].src == nil and runtime.contactInfo["arthas"].unowned ~= nil, "only its notes clear")
    assert(calls[#calls] == "refresh" and calls[#calls - 1] == "icons", "icons then window refresh")
  end

  -- test_refusing_leaves_someone_elses_preview_slot_alone
  do
    local runtime = makeRuntime()
    local reg = runtime.addonIntegrations
    reg.touch("CraftAlert")
    reg.claim("preview", "pv", "CraftAlert")
    runtime.externalPreview.set("zz", { sender = "x", text = "y" })
    reg.setAllowed("CraftAlert", false)
    assert(runtime.externalPreview.keyOf() == "zz")
  end

  -- test_a_raising_step_stops_no_other_step
  do
    local runtime, calls = makeRuntime(nil, { openPanel = "ca", hideRaises = true })
    local reg = runtime.addonIntegrations
    reg.touch("CraftAlert")
    reg.claim("panel", "ca", "CraftAlert")
    reg.claim("note", "src", "CraftAlert")
    ContactInfo.Set(runtime.contactInfo, "src", "Arthas", "note")
    reg.setAllowed("CraftAlert", false)
    assert(next(runtime.contactInfo) == nil, "notes cleared though hidePanel raised")
    assert(calls[#calls] == "icons" or calls[#calls] == "refresh")
  end

  -- test_allowing_again_shows_the_tab_without_a_popup_when_it_connected_allowed
  withPopups(function(popups)
    local runtime, calls = makeRuntime()
    local reg = runtime.addonIntegrations
    reg.touch("CraftAlert")
    reg.claim("panel", "ca", "CraftAlert")
    reg.setAllowed("CraftAlert", false)
    reg.setAllowed("CraftAlert", true)
    assert(
      calls[#calls - 2] == "apply:ca" and calls[#calls - 1] == "badge:ca" and calls[#calls] == "icons",
      "tab back, badge re-read, icons refreshed"
    )
    assert(#popups.shown == 0, "no popup for a row that connected allowed")
  end)

  -- test_allowing_again_refreshes_the_badge_of_each_owned_panel_even_if_one_raises
  withPopups(function()
    local runtime, calls = makeRuntime(nil, { badgeRaises = true })
    local reg = runtime.addonIntegrations
    reg.touch("CraftAlert")
    reg.claim("panel", "a", "CraftAlert")
    reg.claim("panel", "b", "CraftAlert")
    reg.setAllowed("CraftAlert", false)
    for i = #calls, 1, -1 do
      calls[i] = nil
    end
    reg.setAllowed("CraftAlert", true)
    local seen = table.concat(calls, ",")
    assert(seen:find("badge:a", 1, true) and seen:find("badge:b", 1, true), "both badges refreshed, got " .. seen)
    assert(calls[#calls] == "icons", "later steps still run, got " .. seen)
  end)

  -- test_allowing_again_without_a_window_still_applies_the_tab
  withPopups(function()
    local runtime, calls = makeRuntime()
    runtime.window = nil
    local reg = runtime.addonIntegrations
    reg.touch("CraftAlert")
    reg.claim("panel", "ca", "CraftAlert")
    reg.setAllowed("CraftAlert", false)
    reg.setAllowed("CraftAlert", true)
    assert(calls[#calls - 1] == "apply:ca" and calls[#calls] == "icons")
  end)

  -- test_ticking_a_row_that_connected_refused_asks_for_a_reload
  withPopups(function(popups)
    local runtime = makeRuntime({ Late = { title = "Late", allowed = false } })
    local reg = runtime.addonIntegrations
    reg.touch("Late")
    assert(reg.connectedRefused("Late") == true)
    reg.setAllowed("Late", true)
    assert(reg.isAllowed("Late") == true, "the tick is saved and applies at once")
    assert(#popups.shown == 1 and popups.shown[1] == "WHISPER_MESSENGER_RELOAD_UI", "reload popup")
    reg.setAllowed("Late", false)
    reg.setAllowed("Late", true)
    assert(#popups.shown == 2, "every tick of such a row asks again")
  end)

  -- test_attach_without_a_registry_does_nothing
  do
    IntegrationAccess.Attach({})
  end

  -- test_published_api_is_wired (Publish attaches it)
  do
    local runtime, api = PublicApiEnv.Initialize({})
    local handle = api.Connect("CA")
    assert(handle.SetContactInfo("src", "Jaina-Proudmoore", "hello") == true)
    assert(next(runtime.contactInfo) ~= nil)
    runtime.addonIntegrations.setAllowed("CA", false)
    assert(next(runtime.contactInfo) == nil, "unticking through the real wiring clears its notes")
    PublicApiEnv.Reset()
  end
end
