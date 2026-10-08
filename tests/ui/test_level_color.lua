local LevelColor = require("WhisperMessenger.UI.LevelColor")
local UIHelpers = require("WhisperMessenger.UI.Helpers")
local Theme = require("WhisperMessenger.UI.Theme")

local function stubDifficulty(fn)
  _G.GetQuestDifficultyColor = fn
end

return function()
  local savedDifficulty = _G.GetQuestDifficultyColor
  local fallback = UIHelpers.colorEscape(Theme.COLORS.text_secondary)

  -- test_uses_the_quest_difficulty_color

  do
    local seen
    stubDifficulty(function(level)
      seen = level
      return { r = 1, g = 0.1, b = 0.1 }
    end)
    assert(LevelColor.Escape(30) == "|cffff1a1a", "the difficulty colour becomes the escape")
    assert(seen == 30, "the level is passed to the difficulty function")
  end

  -- test_missing_function_falls_back_to_secondary_text

  do
    stubDifficulty(nil)
    assert(LevelColor.Escape(30) == fallback, "no difficulty function gives the secondary text colour")
  end

  -- test_throwing_function_falls_back

  do
    stubDifficulty(function()
      error("boom")
    end)
    local ok, escape = pcall(LevelColor.Escape, 30)
    assert(ok, "a throwing difficulty function raises no error")
    assert(escape == fallback, "a throwing difficulty function gives the fallback")
  end

  -- test_result_without_red_falls_back

  do
    stubDifficulty(function()
      return {}
    end)
    assert(LevelColor.Escape(30) == fallback, "a colour without r gives the fallback")
    stubDifficulty(function()
      return "yellow"
    end)
    assert(LevelColor.Escape(30) == fallback, "a non-table result gives the fallback")
  end

  stubDifficulty(savedDifficulty)
end
