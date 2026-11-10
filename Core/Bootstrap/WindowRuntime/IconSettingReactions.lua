local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- What a changed Icons-page setting does to the floating widget and the
-- minimap button once the value is saved. Either icon may be absent.
local IconSettingReactions = {}

function IconSettingReactions.Apply(key, value, icon, minimap)
  if key == "iconDesaturated" then
    if icon and icon.refreshDesaturation then
      icon.refreshDesaturation()
    end
    if minimap and minimap.refreshDesaturation then
      minimap.refreshDesaturation()
    end
  end
  -- Widget-only looks: the minimap always wears the gold ring.
  local repaintsIcon = key == "iconBorder" or key == "iconBorderThemed" or key == "iconBackground" or key == "widgetShape"
  if repaintsIcon and icon and icon.refreshTheme then
    icon.refreshTheme()
  end
  if key == "widgetTransparency" and icon and icon.refreshTransparency then
    icon.refreshTransparency()
  end
  if key == "lockToggleIcon" and icon and icon.refreshLockGlyph then
    icon.refreshLockGlyph()
  end

  -- Widget-only: the minimap button and the preview card keep their strata.
  if key == "widgetStrata" and icon and icon.applyStrata then
    icon.applyStrata(value)
  end

  if key == "widgetPreviewPosition" then
    if icon and icon.applyPreviewPosition then
      icon.applyPreviewPosition(value)
    end
    if minimap and minimap.applyPreviewPosition then
      minimap.applyPreviewPosition(value)
    end
  end
end

ns.BootstrapWindowRuntimeIconSettingReactions = IconSettingReactions

return IconSettingReactions
