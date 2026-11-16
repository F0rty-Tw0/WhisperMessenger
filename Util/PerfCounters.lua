local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Session counters for /wmsg perf: how much work incoming chat causes, plus
-- how much chat history is saved. The readout is a developer debug aid, so
-- its lines are not localized.
local PerfCounters = {}

local ORDER = { "groupLines", "channelLines", "unknownChannelIDs", "ignored", "ruleBlocked", "collapsed", "refreshes", "snapshotBuilds" }

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
    lines[#lines + 1] = counter .. ": " .. PerfCounters.Get(counter)
  end
  lines[#lines + 1] = profilerLine(name)
  lines[#lines + 1] = storedLine(getConversations)
  return lines
end

ns.PerfCounters = PerfCounters
return PerfCounters
