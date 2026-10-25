local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")
local IgnoreList = ns.IgnoreList or require("WhisperMessenger.Model.Filters.IgnoreList")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

-- IsBlocked(name), Block(name), Unblock(name): the account-wide block list.
-- name is "Name" or "Name-Realm". IsBlocked is true for a live (unexpired)
-- entry. Block is true once the player is blocked; an existing live entry is
-- kept as is, a new one is permanent with no reason. Unblock is true once the
-- player is not blocked. A bad name (not a string, blank, secret) or an
-- internal error returns false and changes nothing.
local BlockList = {}

local function isValidName(name)
  if SecretValue.Is(name) then
    return false
  end
  return Guards.IsNonEmptyString(name) and IgnoreList.Key(name) ~= nil
end

local function readClock(runtime)
  return type(runtime.now) == "function" and runtime.now() or nil
end

local function filtersChanged(runtime)
  if type(runtime.syncChatFilters) == "function" then
    runtime.syncChatFilters()
  end
  if runtime.isWindowVisible() then
    runtime.refreshWindow()
  end
end

function BlockList.Install(api, runtime)
  api.IsBlocked = Guards.Wrap(function(name)
    if not isValidName(name) then
      return false
    end
    local filters = IgnoreList.Ensure(runtime.accountState)
    return IgnoreList.Lookup(filters, name, readClock(runtime)) ~= nil
  end)

  api.Block = Guards.Wrap(function(name)
    if not isValidName(name) then
      return false
    end
    local filters = IgnoreList.Ensure(runtime.accountState)
    if IgnoreList.Lookup(filters, name, readClock(runtime)) ~= nil then
      return true
    end
    IgnoreList.Add(filters, name)
    filtersChanged(runtime)
    return true
  end)

  api.Unblock = Guards.Wrap(function(name)
    if not isValidName(name) then
      return false
    end
    IgnoreList.Remove(IgnoreList.Ensure(runtime.accountState), name)
    filtersChanged(runtime)
    return true
  end)
end

ns.PublicApiBlockList = BlockList
return BlockList
