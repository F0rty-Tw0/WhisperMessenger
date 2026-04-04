package.path = "./?.lua;" .. package.path
local Assert = require("tests.helpers.assert")

-- Stub WoW globals
rawset(_G, "time", os.time)
_G.date = os.date

local TimeFormat = require("Util.TimeFormat")

local function tests()
  -- MessageTime produces a time string
  local ts = os.time({ year = 2026, month = 3, day = 19, hour = 14, min = 30, sec = 0 })
  local mt = TimeFormat.MessageTime(ts)
  assert(type(mt) == "string" and #mt > 0, "MessageTime should return non-empty string, got: " .. tostring(mt))

  -- DateSeparator produces a date string
  local ds = TimeFormat.DateSeparator(ts)
  assert(type(ds) == "string" and ds:find("2026"), "DateSeparator should contain year, got: " .. tostring(ds))
  assert(ds:find("March") or ds:find("Mar"), "DateSeparator should contain month, got: " .. tostring(ds))

  -- ContactPreview: recent timestamps
  local recent = os.time() - 30
  Assert.equal(TimeFormat.ContactPreview(recent), "now")

  local fiveMin = os.time() - 300
  Assert.equal(TimeFormat.ContactPreview(fiveMin), "5m")

  local twoHours = os.time() - 7200
  Assert.equal(TimeFormat.ContactPreview(twoHours), "2h")

  -- Relative: recent timestamps
  local justNow = os.time() - 10
  Assert.equal(TimeFormat.Relative(justNow), "just now")

  local threeMin = os.time() - 180
  Assert.equal(TimeFormat.Relative(threeMin), "3 minutes ago")

  local oneHour = os.time() - 3600
  Assert.equal(TimeFormat.Relative(oneHour), "1 hour ago")

  -- IsDifferentDay
  local day1 = os.time({ year = 2026, month = 3, day = 18, hour = 12, min = 0, sec = 0 })
  local day1b = os.time({ year = 2026, month = 3, day = 18, hour = 23, min = 0, sec = 0 })
  local day2 = os.time({ year = 2026, month = 3, day = 19, hour = 12, min = 0, sec = 0 })
  assert(not TimeFormat.IsDifferentDay(day1, day1b), "Same day should return false")
  assert(TimeFormat.IsDifferentDay(day1, day2), "Different days should return true")

  -- Edge cases
  Assert.equal(TimeFormat.MessageTime(nil), "")
  Assert.equal(TimeFormat.MessageTime(0), "")
  Assert.equal(TimeFormat.ContactPreview(nil), "")
  Assert.equal(TimeFormat.Relative(0), "unknown")
  assert(TimeFormat.IsDifferentDay(nil, day1), "nil timestamp should return true")

  print("  All TimeFormat tests passed")
end

return tests
