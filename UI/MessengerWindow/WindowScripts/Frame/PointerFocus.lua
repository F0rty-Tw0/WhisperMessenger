local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PointerFocus = {}

-- The frame under the cursor. Retail has GetMouseFoci (a list); Classic
-- flavors still have GetMouseFocus.
local function mouseFocus()
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

-- True when the frame under the cursor is `frame` or one of its descendants.
function PointerFocus.IsFocusInside(frame)
  local current = mouseFocus()
  while current ~= nil and type(current.GetParent) == "function" do
    if current == frame then
      return true
    end
    current = current:GetParent()
  end
  return false
end

ns.MessengerWindowWindowScriptsFramePointerFocus = PointerFocus

return PointerFocus
