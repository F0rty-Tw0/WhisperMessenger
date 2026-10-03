local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Session counters for /wmsg perf: how much work incoming chat causes.
-- The readout is a developer debug aid, so its lines are not localized.
local PerfCounters = {}

local ORDER = { "groupLines", "channelLines", "ignored", "ruleBlocked", "collapsed", "refreshes", "snapshotBuilds" }

local counts = {}

function PerfCounters.Increment(name)
  counts[name] = (counts[name] or 0) + 1
end

function PerfCounters.Get(name)
  return counts[name] or 0
end

function PerfCounters.Reset()
  counts = {}
end

-- Retail only: the addon profiler's recent average CPU time per frame.
local function profilerLine(name)
  local profiler = _G.C_AddOnProfiler
  local metrics = _G.Enum and _G.Enum.AddOnProfilerMetric
  if type(profiler) ~= "table" or type(profiler.GetAddOnMetric) ~= "function" or metrics == nil or metrics.RecentAverageTime == nil then
    return nil
  end
  local ok, value = pcall(profiler.GetAddOnMetric, name, metrics.RecentAverageTime)
  if not ok or type(value) ~= "number" then
    return nil
  end
  return "recentAverageTime: " .. tostring(value) .. " ms"
end

function PerfCounters.Lines(name)
  local lines = {}
  for _, counter in ipairs(ORDER) do
    lines[#lines + 1] = counter .. ": " .. PerfCounters.Get(counter)
  end
  lines[#lines + 1] = profilerLine(name)
  return lines
end

ns.PerfCounters = PerfCounters
return PerfCounters
