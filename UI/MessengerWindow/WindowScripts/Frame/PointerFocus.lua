local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PointerFocus = {}

-- The frame under the cursor. Retail has GetMouseFoci (a list); Classic
-- flavors still have GetMouseFocus.
function PointerFocus.Current()
  local getMouseFoci = _G.GetMouseFoci
  if type(getMouseFoci) == "function" then
    local foci = getMouseFoci()
    return type(foci) == "table" and foci[1] or nil
  end
  local getMouseFocus = _G.GetMouseFocus
  if type(getMouseFocus) == "function" then
    return getMouseFocus()
  end
  return nil
end

-- The frame under the cursor or its closest ancestor that `matches`.
-- Forbidden frames (nameplates in instances) throw on any method but
-- IsForbidden, and are never ours, so the walk stops there.
function PointerFocus.FindFocusAncestor(matches)
  local current = PointerFocus.Current()
  while current ~= nil and type(current.GetParent) == "function" do
    if type(current.IsForbidden) == "function" and current:IsForbidden() then
      return nil
    end
    if matches(current) then
      return current
    end
    current = current:GetParent()
  end
  return nil
end

ns.MessengerWindowWindowScriptsFramePointerFocus = PointerFocus

return PointerFocus
