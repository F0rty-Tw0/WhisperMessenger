local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Trace = {}
local _enabled = false

setmetatable(Trace, {
  __call = function(_self, ...)
    if _enabled and type(_G.print) == "function" then
      _G.print("[WM]", ...)
    end
  end,
})

function Trace.enable()
  _enabled = true
end

function Trace.disable()
  _enabled = false
end

function Trace.isEnabled()
  return _enabled
end

ns.trace = Trace

return Trace
