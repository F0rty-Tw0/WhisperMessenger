local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local IconClick = {}

-- OnClick shared by the widget and minimap icons. Shift + left-click marks
-- every conversation read and leaves the window alone; any other left-click
-- toggles the window. Only left clicks are registered, so a nil button name
-- (a scripted click) counts as left.
function IconClick.Create(options)
  return function(_self, buttonName)
    if buttonName ~= nil and buttonName ~= "LeftButton" then
      return
    end
    if options.onMarkAllRead and type(_G.IsShiftKeyDown) == "function" and _G.IsShiftKeyDown() then
      options.onMarkAllRead()
      return
    end
    if options.onToggle then
      options.onToggle()
    end
  end
end

ns.ToggleIconIconClick = IconClick
return IconClick
