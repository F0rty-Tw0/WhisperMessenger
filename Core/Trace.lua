local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local function trace(...)
  if type(_G.print) == "function" then
    _G.print("[WM]", ...)
  end
end

ns.trace = trace

return trace
