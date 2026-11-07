local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local IconClick = ns.ToggleIconIconClick or require("WhisperMessenger.UI.ToggleIcon.IconClick")
local IconArt = ns.ToggleIconIconArt or require("WhisperMessenger.UI.ToggleIcon.IconArt")
local IconDrag = ns.ToggleIconIconDrag or require("WhisperMessenger.UI.ToggleIcon.IconDrag")

-- Mouse scripts of the toggle icon: hover, click, press and drag.
local IconScripts = {}

-- Returns the drag handle ({} when the frame cannot take scripts).
function IconScripts.Attach(frame, deps)
  if not frame.SetScript then
    return {}
  end

  local hover = deps.hover
  local squareLook = deps.squareLook
  local tooltip = deps.tooltip

  -- Hover lifts the circle and returns the back bubble to the accent
  frame:SetScript("OnEnter", function()
    hover.active = true
    deps.syncLockGlyphVisibility()
    deps.refreshTransparency()
    IconArt.PaintFace(deps.art, true)
    squareLook.setHover(true) -- after the repaint: the square has its own fill
    tooltip.show(deps.getUnreadSummary(), deps.getCompetitiveActive())
  end)

  frame:SetScript("OnLeave", function()
    hover.active = false
    deps.syncLockGlyphVisibility()
    deps.refreshTransparency()
    IconArt.PaintFace(deps.art, false)
    squareLook.setHover(false) -- after the repaint: the square has its own fill
    tooltip.hide()
  end)

  frame:SetScript("OnClick", IconClick.Create(deps.options))

  frame:SetScript("OnMouseDown", function()
    squareLook.setPushed(true)
  end)
  frame:SetScript("OnMouseUp", function()
    squareLook.setPushed(false)
  end)

  return IconDrag.Attach(frame, deps.isLocked, deps.options)
end

ns.ToggleIconIconScripts = IconScripts
return IconScripts
