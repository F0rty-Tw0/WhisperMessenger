local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Picks the icon the window grows from and shrinks into: the floating button
-- when it is up, else the minimap icon (minimap or both mode), else nothing.
-- Also answers whether the grow animation is switched on, read live.
local GrowSource = {}

function GrowSource.Create(options)
  local resolveIconMode = options.resolveIconMode
  local getWidgetIcon = options.getWidgetIcon
  local getMinimapIcon = options.getMinimapIcon
  local settings = options.settings

  local function getGrowSource()
    local widget = getWidgetIcon()
    if widget and widget.frame:IsVisible() then
      return widget.frame
    end

    local mode = resolveIconMode()
    if mode ~= "minimap" and mode ~= "both" then
      return nil
    end
    local minimap = getMinimapIcon()
    if minimap and minimap.isShown() and minimap.frame:IsVisible() then
      return minimap.frame
    end
    return nil
  end

  local function isGrowAnimationOn()
    return not settings or settings.windowAnimation ~= false
  end

  return { getGrowSource = getGrowSource, isGrowAnimationOn = isGrowAnimationOn }
end

ns.BootstrapWindowRuntimeGrowSource = GrowSource
return GrowSource
