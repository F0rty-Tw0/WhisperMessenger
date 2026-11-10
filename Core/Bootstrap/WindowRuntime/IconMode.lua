local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local IconMode = {}

function IconMode.Resolve(settings)
  local mode = settings and settings.iconMode
  if mode == "minimap" or mode == "both" or mode == "none" then
    return mode
  end
  return "widget"
end

-- Creates the surfaces the mode needs and shows or hides them. Getters, not
-- values: the widget and minimap button are assigned by ensureIcon/ensureMinimap.
function IconMode.Apply(mode, surfaces)
  local showWidget = mode == "widget" or mode == "both"
  local showMinimap = mode == "minimap" or mode == "both"

  if showWidget then
    surfaces.ensureIcon()
  end
  if mode ~= "none" then
    surfaces.ensureMinimap()
  end

  local icon = surfaces.getIcon()
  if icon and icon.frame then
    if showWidget then
      icon.frame:Show()
    else
      icon.frame:Hide()
      if icon.setIncomingPreview then
        icon.setIncomingPreview(nil, nil, nil)
      end
    end
  end
  local minimapIcon = surfaces.getMinimap()
  if minimapIcon and minimapIcon.setShown then
    minimapIcon.setShown(showMinimap)
  end
end

ns.BootstrapWindowRuntimeIconMode = IconMode

return IconMode
