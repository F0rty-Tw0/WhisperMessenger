-- Test harness resolves this module through ./?/init.lua.

return {
  IgnoreList = require("WhisperMessenger.Model.Filters.IgnoreList"),
  KeywordRules = require("WhisperMessenger.Model.Filters.KeywordRules"),
  RulePresets = require("WhisperMessenger.Model.Filters.RulePresets"),
  DuplicateCollapse = require("WhisperMessenger.Model.Filters.DuplicateCollapse"),
}
