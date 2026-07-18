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

  -- MessageTime strips the leading zero in 12h mode ("2:30 PM", not "02:30 PM")
  local pmTs = os.time({ year = 2026, month = 3, day = 19, hour = 14, min = 30, sec = 0 })
  Assert.equal(TimeFormat.MessageTime(pmTs), "2:30 PM")
  local amTs = os.time({ year = 2026, month = 3, day = 19, hour = 9, min = 5, sec = 0 })
  Assert.equal(TimeFormat.MessageTime(amTs), "9:05 AM")
  local noonTs = os.time({ year = 2026, month = 3, day = 19, hour = 12, min = 15, sec = 0 })
  Assert.equal(TimeFormat.MessageTime(noonTs), "12:15 PM")

  -- DateSeparator renders the full English month for May (the full-name
  -- catalog key falls back to "May", never the raw key)
  local mayTs = os.time({ year = 2026, month = 5, day = 10, hour = 12, min = 0, sec = 0 })
  Assert.equal(TimeFormat.DateSeparator(mayTs), "May 10, 2026")

  -- "Yesterday" is based on local calendar midnight, not UTC midnight
  do
    local fixedNow = os.time({ year = 2026, month = 7, day = 18, hour = 23, min = 30, sec = 0 })
    local savedTime = _G.time
    _G.time = function(t)
      if t then
        return os.time(t)
      end
      return fixedNow
    end

    local yesterdayMorning = os.time({ year = 2026, month = 7, day = 17, hour = 10, min = 0, sec = 0 })
    Assert.equal(TimeFormat.ContactPreview(yesterdayMorning), "Yesterday")
    Assert.equal(TimeFormat.Relative(yesterdayMorning), "yesterday")

    local twoDaysAgo = os.time({ year = 2026, month = 7, day = 16, hour = 22, min = 0, sec = 0 })
    assert(TimeFormat.ContactPreview(twoDaysAgo) ~= "Yesterday", "two days ago must not be labeled Yesterday")

    _G.time = savedTime
  end

  -- Edge cases
  Assert.equal(TimeFormat.MessageTime(nil), "")
  Assert.equal(TimeFormat.MessageTime(0), "")
  Assert.equal(TimeFormat.ContactPreview(nil), "")
  Assert.equal(TimeFormat.Relative(0), "unknown")
  assert(TimeFormat.IsDifferentDay(nil, day1), "nil timestamp should return true")

  print("  All TimeFormat tests passed")
end

return tests
