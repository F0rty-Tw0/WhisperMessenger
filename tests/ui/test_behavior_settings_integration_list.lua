local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local AddonIntegrations = require("WhisperMessenger.Model.AddonIntegrations")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")

local HEADING = "Addons using Whisper Messenger"

local function build(integrations, layoutCalls)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  return BehaviorSettings.Create(factory, parent, {}, {
    onChange = function() end,
    onLayoutChanged = function()
      layoutCalls.n = layoutCalls.n + 1
    end,
    integrations = integrations,
  })
end

local function registryWith(names)
  local registry = AddonIntegrations.New({ addonIntegrations = {} }, function(name)
    return name
  end)
  for _, name in ipairs(names) do
    registry.touch(name)
  end
  return registry
end

return function()
  -- test_no_integrations_option_means_no_list
  do
    local result = build(nil, { n = 0 })
    assert(FindUI.text(result.frame, HEADING) == nil, "no list without options.integrations")
  end

  -- test_list_appears_under_the_toggle_when_integrations_are_given
  do
    local base = FindUI.countToggles(build(nil, { n = 0 }).frame)
    local result = build({ registry = registryWith({ "CraftAlert" }), enabled = true }, { n = 0 })
    assert(FindUI.text(result.frame, HEADING), "heading shown on the Behavior page")
    assert(FindUI.countToggles(result.frame) == base + 1, "one checkbox row for the connected addon")
  end

  -- test_list_is_hidden_when_the_global_toggle_was_off_at_load
  do
    local base = FindUI.countToggles(build(nil, { n = 0 }).frame)
    local result = build({ registry = registryWith({ "CraftAlert" }), enabled = false }, { n = 0 })
    assert(FindUI.countToggles(result.frame) == base, "no addon rows while the master switch was off")
    local heading = FindUI.text(result.frame, HEADING)
    assert(heading == nil or heading.parent:IsShown() == false, "heading not visible")
  end

  -- test_ticking_a_row_reports_a_layout_change_to_the_page
  do
    local calls = { n = 0 }
    local result = build({ registry = registryWith({ "CraftAlert" }), enabled = true }, calls)
    local before = calls.n
    FindUI.click(FindUI.toggle(result.frame, "CraftAlert"))
    assert(calls.n > before, "page is asked to re-measure after a tick")
  end

  -- test_page_hooks_reach_the_list_without_error
  do
    local result = build({ registry = registryWith({ "CraftAlert" }), enabled = true }, { n = 0 })
    result.refreshLayout(300)
    result.refreshTheme()
    result.setLanguage()
    assert(FindUI.text(result.frame, HEADING), "list survives the page hooks")
  end

  -- test_reset_to_defaults_leaves_the_list_alone
  do
    local registry = registryWith({ "CraftAlert" })
    local result = build({ registry = registry, enabled = true }, { n = 0 })
    FindUI.click(FindUI.toggle(result.frame, "CraftAlert"))
    assert(registry.isAllowed("CraftAlert") == false, "the click unticks the addon")
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(registry.isAllowed("CraftAlert") == false, "reset does not re-tick addons")
  end
end
