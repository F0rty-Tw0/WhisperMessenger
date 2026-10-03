local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local FiltersSettingsUI = require("tests.helpers.filters_settings_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local FiltersSettings = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings")
local KeywordRules = require("WhisperMessenger.Model.Filters.KeywordRules")

-- Own keyword rules are added and edited in a two-field dialog (name and
-- words); ready-made rules keep their fixed title and edit only their words.

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

local function visibleText(root, text)
  return FindUI.find(root, function(node)
    return node.frameType == "FontString" and node.text == text and node.parent:IsShown()
  end)
end

local function ruleRow(result, label)
  return visibleText(result.frame, label).parent:GetParent()
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_add_rule_asks_for_a_name_and_words
  do
    local filters = { ignored = {}, rules = {} }
    local result, reports = create(filters)
    local specs, restore = FiltersSettingsUI.stubTwoFieldDialog({ { "Boost sellers", "WTS boost" } })
    FindUI.click(FindUI.byLabel(result.frame, "Add rule…"))
    restore()
    local spec = specs[1]
    assert(spec and spec.title == "Add rule…" and spec.accept == "Add", "add dialog shown")
    assert(spec.firstLabel == "Name (optional)" and spec.secondLabel == "Words", "name and words fields")
    assert(spec.firstMaxLetters ~= nil and spec.secondMaxLetters == 255, "both fields capped")
    assert(string.find(spec.hint, "either word is enough", 1, true), "syntax hint under the words")
    local rule = filters.rules[1]
    assert(rule.name == "Boost sellers" and rule.words[1] == "wts" and rule.words[2] == "boost", "named rule saved")
    assert(visibleText(result.frame, "Boost sellers") ~= nil, "listed by its name")
    assert(reports.count == 1, "change reported once")
  end

  -- test_add_rule_without_a_name_lists_its_words
  do
    local filters = { ignored = {}, rules = {} }
    local result = create(filters)
    local _, restore = FiltersSettingsUI.stubTwoFieldDialog({ { "", "wts boost" } })
    FindUI.click(FindUI.byLabel(result.frame, "Add rule…"))
    restore()
    assert(filters.rules[1].name == nil, "no name saved")
    assert(visibleText(result.frame, "wts + boost") ~= nil, "listed by its words")
  end

  -- test_clicking_an_own_rule_edits_its_name_and_words
  do
    local filters = { ignored = {}, rules = { { name = "Boost", words = { "wts", "boost" }, enabled = true, blocked = 3 } } }
    local result, reports = create(filters)
    local specs, restore = FiltersSettingsUI.stubTwoFieldDialog({ { "Carry sellers", "wts carry" } })
    FindUI.click(ruleRow(result, "Boost").editButton)
    restore()
    local spec = specs[1]
    assert(spec and spec.title == "Edit rule…" and spec.accept == "Save", "edit dialog shown")
    assert(spec.firstValue == "Boost" and spec.secondValue == "wts + boost", "primed with name and words")
    local rule = filters.rules[1]
    assert(rule.name == "Carry sellers" and rule.words[2] == "carry", "name and words saved")
    assert(rule.blocked == 3 and rule.enabled == true, "count and state kept")
    assert(visibleText(result.frame, "Carry sellers") ~= nil, "list shows the new name")
    assert(reports.count == 1, "change reported once")
  end

  -- test_own_rule_without_a_name_opens_with_an_empty_name
  do
    local filters = { ignored = {}, rules = { { words = { "wts" }, enabled = true, blocked = 0 } } }
    local result = create(filters)
    local specs, restore = FiltersSettingsUI.stubTwoFieldDialog({})
    FindUI.click(ruleRow(result, "wts").editButton)
    restore()
    assert(specs[1] and specs[1].firstValue == "" and specs[1].secondValue == "wts", "empty name, current words")
  end

  -- test_own_rule_name_is_shown_as_typed
  do
    local filters = { ignored = {}, rules = { { name = "Trade", words = { "wts" }, enabled = true, blocked = 0 } } }
    Localization.Configure({ language = "deDE" })
    local result = create(filters)
    Localization.Configure({ language = "enUS" })
    assert(visibleText(result.frame, "Trade") ~= nil, "a player's own title is never translated")
  end

  -- test_ready_made_rule_edits_only_its_words
  do
    local filters = { ignored = {}, rules = { { presetId = "wtsWtb", name = "WTS / WTB / LFW", words = { "wts/wtb/lfw" }, enabled = true } } }
    local result = create(filters)
    local specs, restore = FiltersSettingsUI.stubTwoFieldDialog({})
    local shown = FiltersSettingsUI.stubPopups({ "wts" })
    FindUI.click(ruleRow(result, "WTS / WTB / LFW").editButton)
    restore()
    assert(#specs == 0, "no name field for a ready-made rule")
    assert(#shown == 1, "the words-only dialog opens")
    assert(filters.rules[1].words[1] == "wts" and filters.rules[1].name == "WTS / WTB / LFW", "words saved, title fixed")
  end

  -- test_edit_saves_to_the_same_rule_after_an_earlier_one_is_removed
  do
    local filters = { ignored = {}, rules = { { words = { "aaa" }, enabled = true }, { words = { "bbb" }, enabled = true } } }
    local result = create(filters)
    local specs, restore = FiltersSettingsUI.stubTwoFieldDialog({})
    FindUI.click(ruleRow(result, "bbb").editButton)
    restore()
    local edited = filters.rules[2]
    KeywordRules.Remove(filters, 1)
    specs[1].onAccept("Named", "ccc")
    assert(edited.words[1] == "ccc" and edited.name == "Named", "the rule being edited gets the new name and words")
    assert(#filters.rules == 1 and filters.rules[1] == edited, "no other rule changes")
  end

  -- test_edit_saves_nothing_once_its_rule_is_gone
  do
    local filters = { ignored = {}, rules = { { words = { "aaa" }, enabled = true }, { words = { "bbb" }, enabled = true } } }
    local result, reports = create(filters)
    local specs, restore = FiltersSettingsUI.stubTwoFieldDialog({})
    FindUI.click(ruleRow(result, "aaa").editButton)
    restore()
    KeywordRules.Remove(filters, 1)
    specs[1].onAccept("Named", "ccc")
    assert(filters.rules[1].words[1] == "bbb" and filters.rules[1].name == nil, "another rule is never overwritten")
    assert(reports.count == 0, "nothing reported")
  end

  -- test_dialog_strings_are_translated
  do
    Localization.Configure({ language = "frFR" })
    assert(Localization.Text("Name (optional)") ~= "Name (optional)", "name label translated")
    assert(Localization.Text("Words") ~= "Words", "words label translated")
    Localization.Configure({ language = "enUS" })
  end

  _G.StaticPopupDialogs = nil
  rawset(_G, "StaticPopup_Show", nil)
end
