local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Loader = {}

function Loader.LoadModule(name, key)
  if ns[key] then
    return ns[key]
  end

  if type(require) == "function" then
    local ok, loaded = pcall(require, name)
    if ok then
      return loaded
    end
  end

  error(key .. " module not available")
end

ns.Loader = Loader

return Loader
