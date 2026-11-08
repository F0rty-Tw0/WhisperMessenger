local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local RetailHud = require("tests.helpers.retail_hud")
local AddonIntegrations = require("WhisperMessenger.Model.AddonIntegrations")
local IntegrationList = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings.IntegrationList")

local HEADING = "Addons using Whisper Messenger"
local EMPTY = "No addons have connected yet."
local TITLES = { CraftAlert = "Craft Alert", Colored = "|cff00ff00Colored|r Addon" }

local function lookup(name)
  return TITLES[name]
end

-- Visible when every frame from the node's parent up to the list frame is shown.
-- FakeUI frames and FontStrings start hidden, so the node's own flag is not read.
local function visibleIn(root, node)
  local frame = node.parent
  while frame ~= nil and frame ~= root.parent do
    if not frame:IsShown() then
      return false
    end
    frame = frame.parent
  end
  return true
end

local function shownText(root, wanted)
  return FindUI.find(root, function(node)
    return node.frameType == "FontString" and node.text == wanted and visibleIn(root, node)
  end)
end

local function build(saved, touched, enabled)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local anchor = factory.CreateFrame("Frame", nil, parent)
  local accountState = { addonIntegrations = saved or {} }
  local registry = AddonIntegrations.New(accountState, lookup)
  for _, name in ipairs(touched or {}) do
    registry.touch(name)
  end
  local layoutCalls = 0
  local list = IntegrationList.Create(factory, parent, anchor, {
    integrations = { registry = registry, enabled = enabled ~= false },
    onLayoutChanged = function()
      layoutCalls = layoutCalls + 1
    end,
  })
  return list, registry, accountState, function()
    return layoutCalls
  end
end

return function()
  -- test_empty_list_shows_heading_and_empty_line
  do
    local list = build({}, {})
    assert(shownText(list.frame, HEADING), "heading shown")
    assert(shownText(list.frame, EMPTY), "empty line shown")
    assert(list.bottom ~= nil, "bottom is returned for the next control to anchor under")
  end

  -- test_seen_addon_row_is_a_ticked_checkbox_with_its_title
  do
    local list = build({}, { "CraftAlert" })
    assert(FindUI.isToggleOn(FindUI.toggle(list.frame, "Craft Alert")) == true, "new addon starts ticked")
    assert(shownText(list.frame, EMPTY) == nil, "no empty line once a row exists")
    assert(shownText(list.frame, "Not loaded") == nil, "a seen addon is not 'Not loaded'")
  end

  -- test_colour_coded_title_is_shown_as_given
  do
    local list = build({}, { "Colored" })
    assert(shownText(list.frame, "|cff00ff00Colored|r Addon"), "title keeps its colour codes")
  end

  -- test_unticking_saves_the_choice_and_relays_out
  do
    local list, registry, _, layoutCalls = build({}, { "CraftAlert" })
    local before = layoutCalls()
    FindUI.click(FindUI.toggle(list.frame, "Craft Alert"))
    assert(registry.isAllowed("CraftAlert") == false, "untick refuses the addon")
    assert(FindUI.isToggleOn(FindUI.toggle(list.frame, "Craft Alert")) == false, "checkbox shows unticked")
    assert(layoutCalls() > before, "list reports a layout change after a tick")
  end

  -- test_ticking_again_allows_the_addon
  do
    local list, registry = build({}, { "CraftAlert" })
    local box = FindUI.toggle(list.frame, "Craft Alert")
    FindUI.click(box)
    FindUI.click(FindUI.toggle(list.frame, "Craft Alert"))
    assert(registry.isAllowed("CraftAlert") == true, "tick allows it again")
  end

  -- test_saved_but_unseen_addon_shows_not_loaded_with_forget
  do
    local list = build({ Old = { title = "Old Addon", allowed = true } }, {})
    assert(FindUI.toggle(list.frame, "Old Addon"), "row exists with the saved title")
    assert(shownText(list.frame, "Not loaded"), "separate Not loaded label")
    assert(shownText(list.frame, "Forget"), "Forget button")
  end

  -- test_not_loaded_checkbox_still_works
  do
    local list, registry = build({ Old = { title = "Old Addon", allowed = true } }, {})
    FindUI.click(FindUI.toggle(list.frame, "Old Addon"))
    assert(registry.isAllowed("Old") == false, "choice is saved for when it loads")
  end

  -- test_forget_removes_the_row_and_the_saved_choice
  do
    local list, _, accountState = build({ Old = { title = "Old Addon", allowed = false } }, {})
    FindUI.click(FindUI.byLabel(list.frame, "Forget"))
    assert(accountState.addonIntegrations.Old == nil, "saved choice removed")
    assert(shownText(list.frame, "Old Addon") == nil, "row no longer shown")
    assert(shownText(list.frame, EMPTY), "empty line returns")
  end

  -- test_seen_rows_have_no_forget_button
  do
    local list = build({}, { "CraftAlert" })
    assert(shownText(list.frame, "Forget") == nil, "Forget only on not-loaded rows")
  end

  -- test_other_addons_row_has_its_label_and_tooltip
  do
    local list = build({}, { AddonIntegrations.SHARED })
    local row = FindUI.byLabel(list.frame, "Other addons")
    local shown
    local saved = _G.GameTooltip
    _G.GameTooltip = {
      SetOwner = function() end,
      SetText = function(_, text)
        shown = text
      end,
      AddLine = function() end,
      Show = function() end,
      Hide = function() end,
    }
    row:GetScript("OnEnter")(row)
    _G.GameTooltip = saved
    assert(shown == "Addons that use Whisper Messenger without naming themselves.", "tooltip explains the row, got " .. tostring(shown))
  end

  -- test_rebound_row_drops_the_other_addons_tooltip
  do
    local list, registry = build({}, { AddonIntegrations.SHARED })
    registry.touch("CraftAlert")
    local row = FindUI.byLabel(list.frame, "Craft Alert")
    assert(row:GetScript("OnEnter") == nil, "the pooled row no longer shows the Other addons tooltip")
  end

  -- test_row_drops_not_loaded_once_the_addon_connects
  do
    local list, registry = build({ Old = { title = "Old Addon", allowed = true } }, {})
    registry.touch("Old")
    assert(shownText(list.frame, "Not loaded") == nil, "label hidden once loaded")
    assert(shownText(list.frame, "Forget") == nil, "Forget hidden once loaded")
  end

  -- test_list_rebuilds_when_the_registry_changes_while_shown
  do
    local list, registry = build({}, {})
    list.frame:Show()
    registry.touch("Late")
    assert(shownText(list.frame, "Late"), "a newly connected addon appears")
    assert(shownText(list.frame, EMPTY) == nil, "empty line gone")
  end

  -- test_list_rebuilds_on_show
  do
    local list, registry = build({}, {})
    list.frame:Hide()
    registry.touch("Later")
    list.frame:Show()
    list.frame:GetScript("OnShow")(list.frame)
    assert(shownText(list.frame, "Later"), "OnShow re-reads the registry")
  end

  -- test_list_is_hidden_when_the_global_toggle_was_off_at_load
  do
    local list = build({}, { "CraftAlert" }, false)
    assert(list.frame:IsShown() == false, "frame hidden")
    assert(shownText(list.frame, HEADING) == nil, "no heading")
    assert(FindUI.countToggles(list.frame) == 0, "no rows built")
    assert(list.bottom ~= nil, "bottom still returned")
  end

  -- test_layout_theme_and_language_hooks_do_not_error
  do
    local list = build({ Old = { title = "Old Addon", allowed = true } }, { "CraftAlert" })
    list.refreshLayout(300)
    list.refreshTheme()
    list.setLanguage()
    assert(shownText(list.frame, HEADING), "heading survives the hooks")
  end

  -- test_native_hud_builds_the_list_with_blizzard_controls
  RetailHud.With(function()
    local list = build({ Old = { title = "Old Addon", allowed = true } }, { "CraftAlert" })
    list.refreshLayout(300)
    list.refreshTheme()
    list.setLanguage()
    assert(shownText(list.frame, HEADING), "heading shown on the Retail banner")
    assert(shownText(list.frame, "Craft Alert"), "seen row shown")
    assert(shownText(list.frame, "Not loaded"), "not-loaded row keeps its label")
    assert(FindUI.countToggles(list.frame) == 0, "rows use Blizzard checkboxes, not switches")
  end)
end
