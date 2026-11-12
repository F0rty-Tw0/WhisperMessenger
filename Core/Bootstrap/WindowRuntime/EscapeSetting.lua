local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- "Esc closes the window": flipping it re-lists the open window and hands the
-- Esc key back or takes it again right away.
local EscapeSetting = {}

-- Applies key when it is the Esc setting; other keys are ignored.
function EscapeSetting.Apply(runtime, key)
  local window = runtime.window
  if key == "escapeClosesWindow" and window and window.refreshEscapeSetting then
    window.refreshEscapeSetting()
  end
end

ns.BootstrapWindowRuntimeEscapeSetting = EscapeSetting

return EscapeSetting
