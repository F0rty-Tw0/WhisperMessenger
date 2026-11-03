local WhoLevels = require("WhisperMessenger.Core.SeenLevelEvents.WhoLevels")

return function()
  -- test_keeps_highest_level_per_name

  do
    local levels = {}
    WhoLevels.Collect(levels, { fullName = "Thrall-Area52", level = 60, area = "Orgrimmar" })
    WhoLevels.Collect(levels, { fullName = "Thrall", level = 70, area = "Orgrimmar" })
    WhoLevels.Collect(levels, { fullName = "Thrall", level = 65, area = "Orgrimmar" })
    assert(levels.thrall == 70, "expected highest level 70, got " .. tostring(levels.thrall))
  end

  -- test_ignores_non_positive_levels

  do
    local levels = {}
    WhoLevels.Collect(levels, { fullName = "Jaina", level = 0, area = "Dalaran" })
    assert(next(levels) == nil, "level 0 must not be collected")
  end

  -- test_system_line_must_match_the_row

  do
    local levels = {}
    local info = { fullName = "Jaina", level = 70, area = "Dalaran" }
    WhoLevels.Collect(levels, info, "Someone joined the channel.")
    assert(next(levels) == nil, "an unrelated system line must not collect a level")
    WhoLevels.Collect(levels, info, "[Jaina]: Level 70 Human Mage - Dalaran")
    assert(levels.jaina == 70, "the reply's own row must collect, got " .. tostring(levels.jaina))
  end
end
