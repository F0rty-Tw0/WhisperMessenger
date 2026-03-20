local Helpers = require("WhisperMessenger.Persistence.Helpers")
return function()
  -- applyDefaults fills nil fields
  local target = { a = 1 }
  Helpers.applyDefaults(target, { a = 99, b = 2, c = 3 })
  assert(target.a == 1, "should not overwrite existing")
  assert(target.b == 2, "should fill nil field")
  assert(target.c == 3, "should fill nil field")

  -- applyDefaults with nil target
  local result = Helpers.applyDefaults(nil, { x = 1 })
  assert(type(result) == "table", "nil target should return table")

  -- applyDefaults with nil defaults
  local t = { a = 1 }
  Helpers.applyDefaults(t, nil)
  assert(t.a == 1, "nil defaults should be no-op")
end
