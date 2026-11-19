local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- What the controller's B button closes in the messenger window: the first
-- open layer from the top, the window itself last.
local GamepadCloseOrder = {}

-- deps: isWindowShown, hideShownPopup, closeOpenDropdown (optional: true
-- when it closed a settings dropdown), compactBack, isOptionsVisible,
-- setOptionsVisible, getVisiblePanel, setPanelVisible, closeWindow.
-- The handler always returns true, so the game never falls back to its own
-- close behavior for the window.
function GamepadCloseOrder.Build(deps)
  return function()
    if not deps.isWindowShown() then
      return true
    end
    if deps.hideShownPopup() then
      return true
    end
    if deps.closeOpenDropdown and deps.closeOpenDropdown() then
      return true
    end
    if deps.compactBack() then
      return true
    end
    if deps.isOptionsVisible() then
      deps.setOptionsVisible(false)
    elseif deps.getVisiblePanel() ~= nil then
      deps.setPanelVisible(nil)
    else
      deps.closeWindow()
    end
    return true
  end
end

ns.MessengerWindowGamepadCloseOrder = GamepadCloseOrder

return GamepadCloseOrder
