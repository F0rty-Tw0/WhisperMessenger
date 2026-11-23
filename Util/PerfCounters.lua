local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Session counters for /wmsg perf: how much work incoming chat causes, plus
-- how much chat history is saved. The readout is a developer debug aid, so
-- its lines are not localized.
local PerfCounters = {}

local ORDER = { "groupLines", "channelLines", "unknownChannelIDs", "ignored", "ruleBlocked", "collapsed", "refreshes", "snapshotBuilds" }

local OTHER_SOURCE = "other"

local counts = {}
-- bySource[counter][source]: increments per source, for counters counted
-- with IncrementBySource. activeSources[counter]: the source Attribute set.
local bySource = {}
local activeSources = {}

function PerfCounters.Increment(name)
  counts[name] = (counts[name] or 0) + 1
end

-- Counts the total plus the active source of the counter ("other" when no
-- Attribute call is running).
function PerfCounters.IncrementBySource(name)
  counts[name] = (counts[name] or 0) + 1
  local sources = bySource[name]
  if sources == nil then
    sources = {}
    bySource[name] = sources
  end
  local source = activeSources[name] or OTHER_SOURCE
  sources[source] = (sources[source] or 0) + 1
end

-- Runs fn(...) with source active for counter and returns its first result.
-- The outermost call wins: a nested Attribute keeps the outer source, so the
-- count names what triggered the work. No pcall, so an error keeps its own
-- stack; it leaves the source set, and later work counts under it.
function PerfCounters.Attribute(counter, source, fn, ...)
  local previous = activeSources[counter]
  if previous == nil then
    activeSources[counter] = source
  end
  local result = fn(...)
  activeSources[counter] = previous
  return result
end

function PerfCounters.Get(name)
  return counts[name] or 0
end

function PerfCounters.GetSource(name, source)
  local sources = bySource[name]
  return sources and sources[source] or 0
end

function PerfCounters.Reset()
  counts = {}
  bySource = {}
end

-- " (ticker 2, other 1)", busiest source first; "" when none was counted.
local function sourceSuffix(name)
  local sources = bySource[name]
  if sources == nil then
    return ""
  end
  local names = {}
  for source in pairs(sources) do
    names[#names + 1] = source
  end
  table.sort(names, function(a, b)
    if sources[a] ~= sources[b] then
      return sources[a] > sources[b]
    end
    return a < b
  end)
  for index, source in ipairs(names) do
    names[index] = source .. " " .. sources[source]
  end
  return " (" .. table.concat(names, ", ") .. ")"
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

-- How much chat history is saved, counted only when the readout is asked for.
local function storedLine(getConversations)
  local conversations = type(getConversations) == "function" and getConversations() or nil
  if type(conversations) ~= "table" then
    return nil
  end
  local chats, messages = 0, 0
  for _, conversation in pairs(conversations) do
    chats = chats + 1
    if type(conversation.messages) == "table" then
      messages = messages + #conversation.messages
    end
  end
  return "stored messages: " .. messages .. " in " .. chats .. " chats"
end

-- getConversations is optional: a function returning the saved conversations
-- keyed by conversation key.
function PerfCounters.Lines(name, getConversations)
  local lines = {}
  for _, counter in ipairs(ORDER) do
    lines[#lines + 1] = counter .. ": " .. PerfCounters.Get(counter) .. sourceSuffix(counter)
  end
  lines[#lines + 1] = profilerLine(name)
  lines[#lines + 1] = storedLine(getConversations)
  return lines
end

ns.PerfCounters = PerfCounters
return PerfCounters
