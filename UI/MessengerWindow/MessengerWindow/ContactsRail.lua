local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Metrics = ns.MessengerWindowLayoutMetrics or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")
local sizeValue = UIHelpers.sizeValue

-- Collapses the contacts pane to the icon rail and back. Owns everything
-- that changes with it: the layout width (through layout.contactsCollapsed),
-- icon-only rows (through windowGeometry), the search magnifier, the hidden
-- scrollbar, the window's resize minimum, and growing a narrow window when
-- the pane expands again. The state is saved with the window position.
local ContactsRail = {}

local function setShown(region, shown)
  if region and region.SetShown then
    region:SetShown(shown)
  end
end

local function effectiveScale(target)
  local scale = target and target.GetEffectiveScale and target:GetEffectiveScale()
  return (type(scale) == "number" and scale > 0) and scale or 1
end

-- options:
--   frame, layout, windowGeometry, chrome
--   relayoutWindow(w, h, contactsWidth, refreshContacts)
--   applyWindowSize(w, h, left)  : resize keeping (or moving to) a left edge
--   onPositionChanged(state)     : saves the window state
function ContactsRail.Create(options)
  local frame = options.frame
  local layout = options.layout
  local geometry = options.windowGeometry
  local theme = options.theme or Theme

  local function applyLook(collapsed)
    layout.contactsCollapsed = collapsed
    if layout.contactsView then
      layout.contactsView.barHidden = collapsed
    end
    setShown(layout.contactsSearchFrame, not collapsed)
    setShown(layout.contactsRailSearchButton, collapsed)
    options.chrome.setContactsCollapsed(collapsed)
  end

  local function relayout()
    local width = sizeValue(frame, "GetWidth", "width", 0)
    local height = sizeValue(frame, "GetHeight", "height", 0)
    options.relayoutWindow(width, height, geometry.getContactsWidth(), true)
  end

  -- Widen a window too narrow for the restored pane. The left edge stays
  -- unless that would push the window off the right of the screen.
  local function growToFit()
    local width = sizeValue(frame, "GetWidth", "width", 0)
    local needed = Metrics.ExpandedWindowWidth(geometry.getContactsWidth(), theme)
    -- Older clients have no GetResizeBounds (only SetMinResize).
    local maxWidth = frame.GetResizeBounds and select(3, frame:GetResizeBounds())
    if type(maxWidth) == "number" and maxWidth > 0 then
      needed = math.min(needed, maxWidth)
    end
    if width >= needed or not options.applyWindowSize then
      return
    end
    local left = frame.GetLeft and frame:GetLeft() or nil
    local parent = frame.GetParent and frame:GetParent() or nil
    if type(left) == "number" and parent then
      local ratio = effectiveScale(parent) / effectiveScale(frame)
      local parentLeft = (parent.GetLeft and parent:GetLeft() or 0) * ratio
      local parentRight = parentLeft + sizeValue(parent, "GetWidth", "width", 0) * ratio
      if left + needed > parentRight then
        left = math.max(parentLeft, parentRight - needed)
      end
    end
    options.applyWindowSize(needed, sizeValue(frame, "GetHeight", "height", 0), left)
  end

  -- expandedWidth: the width to expand to (a divider drag passes the
  -- pointer's); nil keeps the last expanded width. False when unchanged.
  local function apply(collapsed, expandedWidth)
    collapsed = collapsed == true
    if collapsed == (layout.contactsCollapsed == true) then
      return false
    end
    geometry.setCollapsed(collapsed)
    if not collapsed and expandedWidth then
      geometry.setContactsWidth(Metrics.ClampContactsWidth(nil, expandedWidth, theme, true))
    end
    -- Restores the normal resize minimum before the window grows.
    applyLook(collapsed)
    if not collapsed then
      growToFit()
    end
    relayout()
    return true
  end

  local function setCollapsed(collapsed)
    if apply(collapsed) and options.onPositionChanged then
      options.onPositionChanged(geometry.buildState(frame))
    end
  end

  -- Divider drag: no save mid-drag (the drag saves on release). Ignored
  -- while settings are open: the pane is laid out at the nav width then.
  local function snap(collapsed, pointerWidth)
    if not layout.optionsVisible then
      apply(collapsed, pointerWidth)
    end
  end

  -- Settings lay a collapsed window out expanded and closing them brings the
  -- rail back; the saved collapsed state never changes.
  local function setOptionsVisible(visible)
    layout.optionsVisible = visible == true
    if layout.contactsCollapsed then
      relayout()
    end
  end

  local function openSearch()
    setCollapsed(false)
    local input = layout.contactsSearchInput
    if input and input.SetFocus then
      input:SetFocus()
    end
  end

  if layout.contactsRailSearchButton then
    layout.contactsRailSearchButton:SetScript("OnClick", openSearch)
  end

  -- A window saved collapsed opens as the rail.
  if layout.contactsCollapsed then
    applyLook(true)
    relayout()
  end

  return {
    setCollapsed = setCollapsed,
    snap = snap,
    setOptionsVisible = setOptionsVisible,
    isCollapsed = function()
      return layout.contactsCollapsed == true
    end,
    openSearch = openSearch,
  }
end

ns.MessengerWindowContactsRail = ContactsRail

return ContactsRail
