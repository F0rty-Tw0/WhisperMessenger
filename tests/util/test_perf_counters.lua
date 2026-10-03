local PerfCounters = require("WhisperMessenger.Util.PerfCounters")

-- Debug counters behind /wmsg perf: how much work busy chats cause.
return function()
  local savedProfiler = rawget(_G, "C_AddOnProfiler")
  local savedEnum = rawget(_G, "Enum")

  -- test_increment_counts_per_name
  do
    PerfCounters.Reset()
    PerfCounters.Increment("refreshes")
    PerfCounters.Increment("refreshes")
    assert(PerfCounters.Get("refreshes") == 2, "two increments give 2, got " .. PerfCounters.Get("refreshes"))
    assert(PerfCounters.Get("groupLines") == 0, "an untouched counter reads 0")
  end

  -- test_reset_clears_every_counter
  do
    PerfCounters.Increment("collapsed")
    PerfCounters.Reset()
    assert(PerfCounters.Get("collapsed") == 0, "reset clears counters")
  end

  -- test_lines_list_every_counter_without_profiler
  do
    rawset(_G, "C_AddOnProfiler", nil)
    PerfCounters.Reset()
    PerfCounters.Increment("groupLines")
    local lines = PerfCounters.Lines("WhisperMessenger")
    assert(#lines == 8, "one line per counter without the profiler, got " .. #lines)
    assert(string.find(lines[1], "groupLines", 1, true) and string.find(lines[1], "1", 1, true), "first line is groupLines: " .. lines[1])
    assert(string.find(lines[3], "unknownChannelIDs", 1, true), "unknownChannelIDs follows channelLines: " .. lines[3])
    assert(string.find(lines[8], "snapshotBuilds", 1, true), "last line is snapshotBuilds: " .. lines[8])
  end

  -- test_lines_append_profiler_metric_when_available
  do
    local asked
    rawset(_G, "Enum", { AddOnProfilerMetric = { RecentAverageTime = 3 } })
    rawset(_G, "C_AddOnProfiler", {
      GetAddOnMetric = function(name, metric)
        asked = { name = name, metric = metric }
        return 0.25
      end,
    })
    local lines = PerfCounters.Lines("WhisperMessenger")
    assert(#lines == 9, "profiler adds one line, got " .. #lines)
    assert(asked and asked.name == "WhisperMessenger" and asked.metric == 3, "asks the profiler for this addon's recent average")
    assert(string.find(lines[9], "0.25", 1, true), "profiler line shows the metric: " .. lines[9])
  end

  rawset(_G, "C_AddOnProfiler", savedProfiler)
  rawset(_G, "Enum", savedEnum)
end
