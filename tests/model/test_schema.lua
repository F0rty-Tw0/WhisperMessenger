local Schema = require("WhisperMessenger.Persistence.Schema")

return function()
  local db = Schema.NewAccountState()
  assert(db.schemaVersion == 1)
  assert(type(db.conversations) == "table")
  assert(type(db.pendingHydration) == "table")
end
