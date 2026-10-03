-- Test harness resolves this module through ./?/init.lua.

return {
  IgnoreList = require("WhisperMessenger.Model.Filters.IgnoreList"),
  KeywordRules = require("WhisperMessenger.Model.Filters.KeywordRules"),
  DuplicateCollapse = require("WhisperMessenger.Model.Filters.DuplicateCollapse"),
}
