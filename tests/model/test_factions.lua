local Factions = require("WhisperMessenger.Model.Identity.Factions")

return function()
  -- Normal lookups
  assert(Factions.InferFaction("Human") == "Alliance", "Human should be Alliance")
  assert(Factions.InferFaction("Orc") == "Horde", "Orc should be Horde")
  assert(Factions.InferFaction("Pandaren") == nil, "Pandaren should be nil (neutral)")
  assert(Factions.InferFaction(nil) == nil, "nil raceTag should return nil")

  -- Non-string types must not crash (guards against tainted/unexpected values)
  assert(Factions.InferFaction(42) == nil, "numeric raceTag should return nil")
  assert(Factions.InferFaction(true) == nil, "boolean raceTag should return nil")
  assert(Factions.InferFaction({}) == nil, "table raceTag should return nil")
end
