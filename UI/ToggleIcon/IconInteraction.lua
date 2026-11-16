local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local KeybindHints = ns.KeybindHints or require("WhisperMessenger.UI.Shared.KeybindHints")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local captureFramePosition = UIHelpers.captureFramePosition
local IconClick = ns.ToggleIconIconClick or require("WhisperMessenger.UI.ToggleIcon.IconClick")
local IconArt = ns.ToggleIconIconArt or require("WhisperMessenger.UI.ToggleIcon.IconArt")

-- How the toggle icon answers the mouse, each piece a field of one table.
local IconInteraction = {}

-- The toggle icon's hover tooltip: title, unread summary, M+ pause and lock
-- notes, then the keybind and click hints.
local IconTooltip = {}

-- context.badge: the unread badge frame (its visibility gates the summary).
-- context.isLocked: function returning true while the icon is locked.
-- context.options: the icon's Create options (getHideFromDefaultChat).
function IconTooltip.Create(frame, context)
  local badge = context.badge
  local isLocked = context.isLocked
  local options = context.options

  local function show(unreadSummary, isCompetitiveActive)
    if _G.GameTooltip and _G.GameTooltip.SetOwner then
      _G.GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
      local unreadText = badge:IsShown() and " — " .. unreadSummary or ""
      local competitiveText = ""
      if isCompetitiveActive then
        competitiveText = "\n" .. Localization.Text("Paused in M+")
      end
      local lockedText = ""
      if isLocked() then
        lockedText = "\n" .. Localization.Text("Locked")
      end
      _G.GameTooltip:SetText("Whisper Messenger" .. unreadText .. competitiveText .. lockedText)
      KeybindHints.AddToTooltip(_G.GameTooltip, type(options.getHideFromDefaultChat) == "function" and options.getHideFromDefaultChat() == true)
      KeybindHints.AddClickHint(_G.GameTooltip)
      _G.GameTooltip:Show()
    end
  end

  local function hide()
    if _G.GameTooltip and _G.GameTooltip.Hide then
      _G.GameTooltip:Hide()
    end
  end

  return {
    show = show,
    hide = hide,
  }
end

-- Drag-to-move for the toggle icon. A locked icon ignores drag starts; a drop
-- reports the new position through options.onPositionChanged.
local IconDrag = {}

-- Returns { setRideHandlers }. While the icon rides the compact window it is
-- pinned there, so a drag goes to these handlers: { beginDrag, endDrag }.
function IconDrag.Attach(frame, isLocked, options)
  local rideHandlers = nil
  local rideDragging = false

  local function beginDrag()
    if isLocked() then
      return
    end
    if rideHandlers then
      rideDragging = true
      rideHandlers.beginDrag()
      return
    end
    if frame.IsMovable == nil or frame:IsMovable() then
      frame:StartMoving()
    end
  end

  local function endDrag()
    if rideDragging then
      rideDragging = false
      if rideHandlers then
        rideHandlers.endDrag()
      end
      return
    end
    if rideHandlers then
      return
    end
    frame:StopMovingOrSizing()
    local nextState = captureFramePosition(frame)

    if options.onPositionChanged then
      options.onPositionChanged(nextState)
    end
  end

  frame:SetScript("OnDragStart", beginDrag)
  frame:SetScript("OnDragStop", endDrag)

  return {
    setRideHandlers = function(handlers)
      rideHandlers = handlers
    end,
  }
end

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

IconInteraction.IconTooltip = IconTooltip
IconInteraction.IconDrag = IconDrag
IconInteraction.IconScripts = IconScripts

ns.ToggleIconIconInteraction = IconInteraction
return IconInteraction
