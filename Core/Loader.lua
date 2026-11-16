local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Loader = {}

function Loader.LoadModule(name, key)
  if ns[key] then
    return ns[key]
  end

  if type(require) ~= "function" then
    error(key .. " module not available")
  end

  local ok, loaded = pcall(require, name)
  if not ok then
    error(key .. " module failed to load: " .. tostring(loaded))
  end

  return loaded
end

ns.Loader = Loader

return Loader
