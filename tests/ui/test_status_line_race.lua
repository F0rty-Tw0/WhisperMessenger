local StatusLine = require("WhisperMessenger.UI.ConversationPane.StatusLine")
local DisplayName = require("WhisperMessenger.Util.DisplayName")

local function contact(fields)
  local base = { characterName = "Thrall", realm = "Draenor" }
  for k, v in pairs(fields) do
    base[k] = v
  end
  return base
end

local function lineFor(fields, showLevels)
  DisplayName.Configure({ showPlayerLevels = showLevels })
  return (StatusLine.Build(contact(fields), nil))
end

return function()
  local savedDifficulty = _G.GetQuestDifficultyColor
  _G.GetQuestDifficultyColor = function(_level)
    return { r = 1, g = 1, b = 0 }
  end

  -- race sits between the coloured level and the class, faction word dropped
  do
    local line1 = lineFor({ raceName = "Orc", className = "Shaman", characterLevel = 80, factionName = "Horde" }, true)
    assert(line1 == "Thrall-Draenor  -  |cffffff00Level 80|r Orc Shaman", "got: " .. line1)
  end

  -- race with class, levels off
  do
    local line1 = lineFor({ raceName = "Orc", className = "Shaman", characterLevel = 80, factionName = "Horde" }, false)
    assert(line1 == "Thrall-Draenor  -  Orc Shaman", "got: " .. line1)
  end

  -- race with level, no class
  do
    local line1 = lineFor({ raceName = "Orc", characterLevel = 80, factionName = "Horde" }, true)
    assert(line1 == "Thrall-Draenor  -  |cffffff00Level 80|r Orc", "got: " .. line1)
  end

  -- Alliance word dropped too: the icon next to the name shows it
  do
    local line1 = lineFor({ raceName = "Human", className = "Paladin", factionName = "Alliance" }, false)
    assert(line1 == "Thrall-Draenor  -  Human Paladin", "got: " .. line1)
  end

  -- a faction with no icon keeps its word
  do
    local line1 = lineFor({ raceName = "Orco", className = "Shaman", factionName = "Horda" }, false)
    assert(line1 == "Thrall-Draenor  -  Orco Shaman  -  Horda", "got: " .. line1)
  end

  -- neutral race without a faction
  do
    local line1 = lineFor({ raceName = "Pandaren" }, false)
    assert(line1 == "Thrall-Draenor  -  Pandaren", "got: " .. line1)
  end

  -- empty race leaves the line as before
  do
    local line1 = lineFor({ raceName = "", className = "Shaman", factionName = "Horde" }, false)
    assert(line1 == "Thrall-Draenor  -  Shaman  -  Horde", "got: " .. line1)
  end

  -- secret race (lockdown) is treated as unknown
  do
    local savedIsSecret = rawget(_G, "issecretvalue")
    rawset(_G, "issecretvalue", function(value)
      return value == "SECRET_RACE"
    end)
    local line1 = lineFor({ raceName = "SECRET_RACE", className = "Shaman", factionName = "Horde" }, false)
    rawset(_G, "issecretvalue", savedIsSecret)
    assert(line1 == "Thrall-Draenor  -  Shaman  -  Horde", "got: " .. line1)
  end

  _G.GetQuestDifficultyColor = savedDifficulty
  DisplayName.Configure({ showPlayerLevels = false })

  print("  All StatusLine race tests passed")
end
