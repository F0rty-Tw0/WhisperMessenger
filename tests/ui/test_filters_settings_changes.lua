local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local FiltersSettingsUI = require("tests.helpers.filters_settings_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local FiltersSettings = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings")
local KeywordRules = require("WhisperMessenger.Model.Filters.KeywordRules")

-- Every change to the ignore list or the rules reports "filters", so the
-- game-chat filters follow without waiting for a reload.
local NOW = 1000000

-- Opens the words-only edit dialog of the ready-made rule labelled `label` and returns a function
-- that saves `typed` later, as if the player clicked Save after other changes.
local function openEditDialog(result, label)
  local dialog
  _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
  rawset(_G, "StaticPopup_Show", function(name)
    dialog = _G.StaticPopupDialogs[name]
  end)
  FindUI.click(FindUI.text(result.frame, label).parent:GetParent().editButton)
  return function(typed)
    dialog.OnAccept({
      editBox = {
        frameType = "EditBox",
        GetText = function()
          return typed
        end,
        SetText = function() end,
      },
    })
  end
end

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
    local _, restore = FiltersSettingsUI.stubTwoFieldDialog({ { "", "wts boost" } })
    FindUI.click(FindUI.byLabel(result.frame, "Add rule…"))
    restore()
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
    local _, restore = FiltersSettingsUI.stubTwoFieldDialog({ { "", "wts gold" } })
    FindUI.click(FindUI.text(result.frame, "wts").parent:GetParent().editButton)
    restore()
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

  -- test_preset_edit_saves_to_the_same_rule_after_an_earlier_one_is_removed
  do
    local filters =
      { ignored = {}, rules = { { presetId = "a", words = { "aaa" }, enabled = true }, { presetId = "b", words = { "bbb" }, enabled = true } } }
    local result = create(filters)
    local save = openEditDialog(result, "bbb")
    local edited = filters.rules[2]
    KeywordRules.Remove(filters, 1)
    save("ccc")
    assert(edited.words[1] == "ccc", "the rule being edited gets the new words")
    assert(#filters.rules == 1 and filters.rules[1] == edited, "no other rule changes")
  end

  -- test_preset_edit_saves_nothing_once_its_rule_is_gone
  do
    local filters =
      { ignored = {}, rules = { { presetId = "a", words = { "aaa" }, enabled = true }, { presetId = "b", words = { "bbb" }, enabled = true } } }
    local result, reports = create(filters)
    local save = openEditDialog(result, "aaa")
    KeywordRules.Remove(filters, 1)
    save("ccc")
    assert(filters.rules[1].words[1] == "bbb", "another rule is never overwritten")
    assert(reports.count == 0, "nothing reported")
  end

  rawset(_G, "time", nil)
  _G.StaticPopupDialogs = nil
  rawset(_G, "StaticPopup_Show", nil)
end
