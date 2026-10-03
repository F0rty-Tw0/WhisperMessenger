local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local FiltersSettingsUI = require("tests.helpers.filters_settings_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local FiltersSettings = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings")

-- Every change to the ignore list or the rules reports "filters", so the
-- game-chat filters follow without waiting for a reload.
local NOW = 1000000

local function create(filters)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local reports = { count = 0 }
  local result = FiltersSettings.Create(factory, parent, { filters = filters }, {
    onChange = function(key)
      if key == "filters" then
        reports.count = reports.count + 1
      end
    end,
  })
  reports.count = 0
  return result, reports
end

return function()
  Localization.Configure({ language = "enUS" })
  rawset(_G, "time", function()
    return NOW
  end)

  -- test_adding_a_player_reports_a_change
  do
    local result, reports = create({ ignored = {}, rules = {} })
    FiltersSettingsUI.stubPopups({ "Spammer-Realm", "" })
    FindUI.click(FindUI.byLabel(result.frame, "Add player…"))
    assert(reports.count == 1, "add reported once, got " .. reports.count)
  end

  -- test_removing_a_player_reports_a_change
  do
    local filters = { ignored = { bob = { name = "Bob", addedAt = NOW, blocked = 0 } }, rules = {} }
    local result, reports = create(filters)
    FindUI.click(FiltersSettingsUI.trashButtons(result.frame)[1])
    assert(reports.count == 1, "remove reported once, got " .. reports.count)
  end

  -- test_adding_a_rule_reports_a_change
  do
    local result, reports = create({ ignored = {}, rules = {} })
    FiltersSettingsUI.stubPopups({ "wts boost" })
    FindUI.click(FindUI.byLabel(result.frame, "Add rule…"))
    assert(reports.count == 1, "rule add reported once, got " .. reports.count)
  end

  -- test_switching_a_rule_reports_a_change
  do
    local result, reports = create({ ignored = {}, rules = { { words = { "wts" }, enabled = true, blocked = 0 } } })
    FindUI.click(FindUI.toggle(result.frame, "wts"))
    assert(reports.count == 1, "toggle reported once, got " .. reports.count)
  end

  -- test_removing_a_rule_reports_a_change
  do
    local result, reports = create({ ignored = {}, rules = { { words = { "wts" }, enabled = true, blocked = 0 } } })
    FindUI.click(FiltersSettingsUI.trashButtons(result.frame)[1])
    assert(reports.count == 1, "rule remove reported once, got " .. reports.count)
  end

  -- test_editing_a_rule_reports_a_change
  do
    local result, reports = create({ ignored = {}, rules = { { words = { "wts" }, enabled = true, blocked = 0 } } })
    FiltersSettingsUI.stubPopups({ "wts gold" })
    FindUI.click(FindUI.text(result.frame, "wts").parent:GetParent().editButton)
    assert(reports.count == 1, "rule edit reported once, got " .. reports.count)
  end

  -- test_resetting_rules_reports_a_change
  do
    local result, reports = create({ ignored = {}, rules = {} })
    _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
    rawset(_G, "StaticPopup_Show", function(name)
      _G.StaticPopupDialogs[name].OnAccept()
    end)
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(reports.count == 1, "reset reported once, got " .. reports.count)
  end

  rawset(_G, "time", nil)
  _G.StaticPopupDialogs = nil
  rawset(_G, "StaticPopup_Show", nil)
end
