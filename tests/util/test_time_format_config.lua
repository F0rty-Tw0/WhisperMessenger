package.path = "./?.lua;" .. package.path
local Assert = require("tests.helpers.assert")

-- Stub WoW globals
rawset(_G, "time", os.time)
_G.date = os.date
_G.GetServerTime = os.time

local TimeFormat = require("Util.TimeFormat")

local function tests()
  -- Configure exists and accepts a table
  assert(type(TimeFormat.Configure) == "function", "Configure should be a function")
  assert(type(TimeFormat.GetConfig) == "function", "GetConfig should be a function")

  -- Default config
  local defaults = TimeFormat.GetConfig()
  Assert.equal(defaults.timeFormat, "12h")
  Assert.equal(defaults.timeSource, "local")

  -- Configure with 24h format
  TimeFormat.Configure({ timeFormat = "24h" })
  local cfg = TimeFormat.GetConfig()
  Assert.equal(cfg.timeFormat, "24h")
  Assert.equal(cfg.timeSource, "local")

  -- MessageTime respects 24h format
  local ts = os.time({ year = 2026, month = 3, day = 19, hour = 14, min = 30, sec = 0 })
  TimeFormat.Configure({ timeFormat = "24h" })
  local mt24 = TimeFormat.MessageTime(ts)
  assert(mt24:find("14:30"), "24h format should show 14:30, got: " .. tostring(mt24))

  TimeFormat.Configure({ timeFormat = "12h" })
  local mt12 = TimeFormat.MessageTime(ts)
  assert(mt12:find("2:30") or mt12:find("02:30"), "12h format should show 2:30 PM, got: " .. tostring(mt12))
  assert(mt12:find("PM"), "12h format should contain PM, got: " .. tostring(mt12))

  -- Configure with server time source
  TimeFormat.Configure({ timeSource = "server" })
  local cfg2 = TimeFormat.GetConfig()
  Assert.equal(cfg2.timeSource, "server")

  -- now() uses GetServerTime when source is server
  local called = false
  local originalGetServerTime = _G.GetServerTime
  _G.GetServerTime = function()
    called = true
    return 1000000
  end
  TimeFormat.Configure({ timeSource = "server" })
  -- ContactPreview calls now() internally, so if GetServerTime is called, source works
  TimeFormat.ContactPreview(999970)
  assert(called, "GetServerTime should be called when timeSource is 'server'")
  _G.GetServerTime = originalGetServerTime

  -- Reset to local source
  TimeFormat.Configure({ timeSource = "local" })
  local cfg3 = TimeFormat.GetConfig()
  Assert.equal(cfg3.timeSource, "local")

  -- Configure merges partial updates
  TimeFormat.Configure({ timeFormat = "24h", timeSource = "server" })
  TimeFormat.Configure({ timeFormat = "12h" })
  local cfg4 = TimeFormat.GetConfig()
  Assert.equal(cfg4.timeFormat, "12h")
  Assert.equal(cfg4.timeSource, "server")

  -- Invalid values are ignored
  TimeFormat.Configure({ timeFormat = "bogus" })
  Assert.equal(TimeFormat.GetConfig().timeFormat, "12h")
  TimeFormat.Configure({ timeSource = "bogus" })
  Assert.equal(TimeFormat.GetConfig().timeSource, "server")

  -- DateSeparator respects server time offset
  -- Simulate a server 5 hours ahead of local: a timestamp near local midnight
  -- should show the NEXT day when server source is active.
  TimeFormat.Configure({ timeSource = "server" })
  local localMidnight = os.time({ year = 2026, month = 6, day = 15, hour = 23, min = 30, sec = 0 })
  -- With server +5h offset, 23:30 local = 04:30 next day on server
  _G.C_DateAndTime = {
    GetCurrentCalendarTime = function()
      local lt = os.date("*t")
      return {
        year = lt.year,
        month = lt.month,
        monthDay = lt.day,
        hour = lt.hour + 5,
        minute = lt.min,
        second = lt.sec,
      }
    end,
  }
  TimeFormat.Configure({ timeSource = "server" }) -- re-configure to pick up offset
  local serverDateStr = TimeFormat.DateSeparator(localMidnight)
  assert(
    serverDateStr:find("June 16") or serverDateStr:find("Jun 16"),
    "Server time +5h should show June 16 for 23:30 local, got: " .. tostring(serverDateStr)
  )

  -- IsDifferentDay respects server time offset
  -- Two timestamps on same local day but different server days
  local lateNight = os.time({ year = 2026, month = 6, day = 15, hour = 22, min = 0, sec = 0 })
  local justBefore = os.time({ year = 2026, month = 6, day = 15, hour = 20, min = 0, sec = 0 })
  -- Server: 22:00+5=03:00 Jun 16, 20:00+5=01:00 Jun 16 → same server day
  assert(not TimeFormat.IsDifferentDay(justBefore, lateNight), "Both should be same server day (June 16)")
  -- Compare across local day boundary in server time
  local beforeServerMidnight = os.time({ year = 2026, month = 6, day = 15, hour = 18, min = 0, sec = 0 })
  -- Server: 18:00+5=23:00 Jun 15 vs 22:00+5=03:00 Jun 16 → different server days
  assert(
    TimeFormat.IsDifferentDay(beforeServerMidnight, lateNight),
    "18:00 local (23:00 server Jun 15) vs 22:00 local (03:00 server Jun 16) should be different days"
  )

  -- Clean up and switch back to local
  _G.C_DateAndTime = nil
  TimeFormat.Configure({ timeFormat = "12h", timeSource = "local" })

  -- IsDifferentDay in local mode uses local timezone (not UTC epoch division)
  local localDay1 = os.time({ year = 2026, month = 3, day = 18, hour = 23, min = 59, sec = 0 })
  local localDay2 = os.time({ year = 2026, month = 3, day = 19, hour = 0, min = 1, sec = 0 })
  assert(TimeFormat.IsDifferentDay(localDay1, localDay2), "23:59 and 00:01 should be different local days")

  -- ContactPreview / Relative date labels must honor server offset.
  -- Install a +1h server offset via C_DateAndTime; then verify that the date()
  -- formatter receives the offset timestamp, not the raw one.
  do
    _G.C_DateAndTime = {
      GetCurrentCalendarTime = function()
        local lt = os.date("*t")
        return {
          year = lt.year,
          month = lt.month,
          monthDay = lt.day,
          hour = lt.hour + 1,
          minute = lt.min,
          second = lt.sec,
        }
      end,
    }
    TimeFormat.Configure({ timeFormat = "12h", timeSource = "server" })

    local fakeNow = os.time({ year = 2026, month = 6, day = 15, hour = 12, min = 0, sec = 0 })
    _G.GetServerTime = function()
      return fakeNow
    end

    local dayNameCalls, shortDateCalls, longDateCalls = {}, {}, {}
    local originalDate = _G.date
    _G.date = function(fmt, ts)
      if fmt == "%a" then
        table.insert(dayNameCalls, ts)
      elseif fmt == "%b %d" then
        table.insert(shortDateCalls, ts)
      elseif fmt == "%b %d, %Y" then
        table.insert(longDateCalls, ts)
      end
      return originalDate(fmt, ts)
    end

    local threeDaysAgo = fakeNow - 3 * 86400
    local twoWeeksAgo = fakeNow - 14 * 86400
    TimeFormat.ContactPreview(threeDaysAgo) -- %a branch
    TimeFormat.ContactPreview(twoWeeksAgo) -- %b %d branch
    TimeFormat.Relative(twoWeeksAgo) -- %b %d, %Y branch

    _G.date = originalDate

    assert(#dayNameCalls == 1, "ContactPreview should have called date('%a', ...) once")
    assert(
      dayNameCalls[1] ~= threeDaysAgo,
      "ContactPreview %a branch should apply server offset, got raw timestamp " .. tostring(dayNameCalls[1])
    )
    assert(
      dayNameCalls[1] == threeDaysAgo + 3600,
      "ContactPreview %a branch should add +3600s server offset, got diff " .. tostring(dayNameCalls[1] - threeDaysAgo)
    )

    assert(#shortDateCalls == 1, "ContactPreview should have called date('%b %d', ...) once")
    assert(
      shortDateCalls[1] == twoWeeksAgo + 3600,
      "ContactPreview %b %d branch should add +3600s server offset, got diff "
        .. tostring(shortDateCalls[1] - twoWeeksAgo)
    )

    assert(#longDateCalls == 1, "Relative should have called date('%b %d, %Y', ...) once")
    assert(
      longDateCalls[1] == twoWeeksAgo + 3600,
      "Relative %b %d, %Y branch should add +3600s server offset, got diff " .. tostring(longDateCalls[1] - twoWeeksAgo)
    )

    _G.C_DateAndTime = nil
    TimeFormat.Configure({ timeFormat = "12h", timeSource = "local" })
  end

  print("  All TimeFormat config tests passed")
end

return tests
