local TableUtils = require("WhisperMessenger.Util.TableUtils")

return function()
  -- copyState
  local original = { a = 1, b = "two" }
  local copy = TableUtils.copyState(original)
  assert(copy.a == 1, "copyState should copy values")
  assert(copy.b == "two", "copyState should copy string values")
  copy.a = 99
  assert(original.a == 1, "copyState should be a shallow copy")

  local nilCopy = TableUtils.copyState(nil)
  assert(type(nilCopy) == "table", "copyState(nil) should return empty table")

  -- clamp
  assert(TableUtils.clamp(5, 0, 10) == 5, "clamp should return value in range")
  assert(TableUtils.clamp(-1, 0, 10) == 0, "clamp should clamp to minimum")
  assert(TableUtils.clamp(15, 0, 10) == 10, "clamp should clamp to maximum")

  -- unpackValues
  local a, b, c = TableUtils.unpackValues({ 10, 20, 30 })
  assert(a == 10 and b == 20 and c == 30, "unpackValues should unpack table")

  -- sumBy
  local items = {
    { count = 3 },
    { count = 7 },
    { count = 0 },
  }
  assert(TableUtils.sumBy(items, "count") == 10, "sumBy should sum field values")
  assert(TableUtils.sumBy(nil, "count") == 0, "sumBy(nil) should return 0")

  -- findWhere
  local contacts = {
    { name = "Alice", id = 1 },
    { name = "Bob", id = 2 },
  }
  local found = TableUtils.findWhere(contacts, "name", "Bob")
  assert(found and found.id == 2, "findWhere should find matching item")
  local notFound = TableUtils.findWhere(contacts, "name", "Charlie")
  assert(notFound == nil, "findWhere should return nil when not found")
end
