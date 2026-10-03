local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local KeywordRules = ns.KeywordRules or require("WhisperMessenger.Model.Filters.KeywordRules")
local TextInputDialog = ns.TextInputDialog or require("WhisperMessenger.UI.Shared.TextInputDialog")
local TwoFieldDialog = ns.TwoFieldDialog or require("WhisperMessenger.UI.Shared.TwoFieldDialog")

-- The Filters page's keyword-rule dialogs: own rules are added and edited
-- with a name and their words; a ready-made rule's title is fixed, so it
-- edits only its words.
local RuleDialogs = {}

local PRESET_EDIT_DIALOG = "WHISPER_MESSENGER_EDIT_KEYWORD_RULE"
local RULE_MAX_LETTERS = 255
local NAME_MAX_LETTERS = 48
-- The short syntax lines from the page's "How filters work" section.
local SYNTAX_HINTS = {
  "gold + cheap: both words must appear, in any order.",
  "wts/wtb: either word is enough.",
  '"lf": whole word only, so "half" doesn\'t match.',
}

local function text(key)
  return Localization.Text(key)
end

local function syntaxHint()
  local lines = {}
  for index, key in ipairs(SYNTAX_HINTS) do
    lines[index] = text(key)
  end
  return table.concat(lines, "\n")
end

-- The dialogs don't block the page: rules may move or go before Save.
local function indexOf(rules, rule)
  for index, candidate in ipairs(rules) do
    if candidate == rule then
      return index
    end
  end
  return nil
end

local function showNameAndWords(factory, spec)
  TwoFieldDialog.Show(factory, {
    title = spec.title,
    accept = spec.accept,
    firstLabel = text("Name (optional)"),
    secondLabel = text("Words"),
    hint = syntaxHint(),
    firstValue = spec.name,
    secondValue = spec.words,
    firstMaxLetters = NAME_MAX_LETTERS,
    secondMaxLetters = RULE_MAX_LETTERS,
    onAccept = spec.onAccept,
  })
end

function RuleDialogs.Add(factory, filters, onChanged)
  showNameAndWords(factory, {
    title = text("Add rule…"),
    accept = text("Add"),
    onAccept = function(name, words)
      if KeywordRules.Add(filters, words, name) ~= nil then
        onChanged()
      end
    end,
  })
end

local function editPresetWords(filters, rule, onChanged)
  TextInputDialog.Show(PRESET_EDIT_DIALOG, {
    prompt = text("Edit rule…"),
    accept = text("Save"),
    maxLetters = RULE_MAX_LETTERS,
    value = KeywordRules.Format(rule),
    onAccept = function(typed)
      local index = indexOf(filters.rules, rule)
      if index ~= nil and KeywordRules.SetWords(filters, index, typed) ~= nil then
        onChanged()
      end
    end,
  })
end

function RuleDialogs.Edit(factory, filters, rule, onChanged)
  if rule.presetId ~= nil then
    editPresetWords(filters, rule, onChanged)
    return
  end
  showNameAndWords(factory, {
    title = text("Edit rule…"),
    accept = text("Save"),
    name = rule.name or "",
    words = KeywordRules.Format(rule),
    onAccept = function(name, words)
      local index = indexOf(filters.rules, rule)
      if index ~= nil and KeywordRules.SetWords(filters, index, words) ~= nil then
        KeywordRules.SetName(filters, index, name)
        onChanged()
      end
    end,
  })
end

ns.FiltersSettingsRuleDialogs = RuleDialogs
return RuleDialogs
