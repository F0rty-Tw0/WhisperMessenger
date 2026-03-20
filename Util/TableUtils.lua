local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TableUtils = {}

function TableUtils.copyState(source)
  local copy = {}
  for key, value in pairs(source or {}) do
    copy[key] = value
  end
  return copy
end

function TableUtils.clamp(value, minimum, maximum)
  if value < minimum then
    return minimum
  end
  if value > maximum then
    return maximum
  end
  return value
end

function TableUtils.unpackValues(values)
  local unpackFn = table.unpack or _G.unpack
  if type(unpackFn) ~= "function" then
    error("unpack not available")
  end
  return unpackFn(values)
end

function TableUtils.sumBy(items, fieldName)
  local total = 0
  for _, item in ipairs(items or {}) do
    total = total + (item[fieldName] or 0)
  end
  return total
end

function TableUtils.findWhere(items, fieldName, value)
  for _, item in ipairs(items or {}) do
    if item[fieldName] == value then
      return item
    end
  end
  return nil
end

ns.TableUtils = TableUtils

return TableUtils
