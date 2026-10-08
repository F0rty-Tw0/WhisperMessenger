local StatusLine = require("WhisperMessenger.UI.ConversationPane.StatusLine")
local DisplayName = require("WhisperMessenger.Util.DisplayName")

local function contact(fields)
  local base = { characterName = "Thrall", realm = "Draenor" }
  for k, v in pairs(fields) do
    base[k] = v
  end
  return base
end

local function stubDifficulty(fn)
  _G.GetQuestDifficultyColor = fn
end

return function()
  local savedDifficulty = _G.GetQuestDifficultyColor
  stubDifficulty(function(_level)
    return { r = 1, g = 1, b = 0 }
  end)

  -- option off hides a known level
  do
    DisplayName.Configure({ showPlayerLevels = false })
    local line1 = StatusLine.Build(contact({ className = "Shaman", characterLevel = 80, factionName = "Horde" }), nil)
    assert(line1 == "Thrall-Draenor  -  Shaman  -  Horde", "got: " .. line1)
  end

  -- option on: coloured level joins the class chunk
  do
    DisplayName.Configure({ showPlayerLevels = true })
    local line1 = StatusLine.Build(contact({ className = "Shaman", characterLevel = 80, factionName = "Horde" }), nil)
    assert(line1 == "Thrall-Draenor  -  |cffffff00Level 80|r Shaman  -  Horde", "got: " .. line1)
  end

  -- option on: level without a class stands alone in the class slot
  do
    DisplayName.Configure({ showPlayerLevels = true })
    local line1 = StatusLine.Build(contact({ characterLevel = 80 }), nil)
    assert(line1 == "Thrall-Draenor  -  |cffffff00Level 80|r", "got: " .. line1)
  end

  -- option on: no level leaves the line unchanged
  do
    DisplayName.Configure({ showPlayerLevels = true })
    local line1 = StatusLine.Build(contact({ className = "Shaman", factionName = "Horde" }), nil)
    assert(line1 == "Thrall-Draenor  -  Shaman  -  Horde", "got: " .. line1)
  end

  stubDifficulty(savedDifficulty)
  DisplayName.Configure({ showPlayerLevels = false })

  print("  All StatusLine level tests passed")
end
