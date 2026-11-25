local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Where an opening drop-down list goes. The settings page clips what sticks
-- out of its view, and the controller's D-pad would walk on into the cut-off
-- rows. With no room below its button the page scrolls down; a list that still
-- has none opens above it, and one that fits on neither side shows fewer rows
-- on the roomier side.
local DropdownPlacement = {}

local GAP = 2

-- The scroll view the page is in, or nil outside one.
local function viewOf(button)
  local frame = button:GetParent()
  while frame do
    if frame:GetObjectType() == "ScrollFrame" then
      return frame
    end
    frame = frame:GetParent()
  end
  return nil
end

-- Space above and below the button inside `view`; nil without a view or
-- before the game has laid them out.
local function roomAround(view, button)
  if not view then
    return nil
  end
  local viewTop, viewBottom = view:GetTop(), view:GetBottom()
  local top, bottom = button:GetTop(), button:GetBottom()
  if not (viewTop and viewBottom and top and bottom) then
    return nil
  end
  return viewTop - top, bottom - viewBottom
end

-- Scrolls the page down by up to `missing`, keeping what is `above` the
-- button's top in view. Returns how far it went.
local function scrollPage(view, missing, above)
  local offset = view:GetVerticalScroll()
  local distance = math.min(missing, above, view:GetVerticalScrollRange() - offset)
  if distance <= 0 then
    return 0
  end
  view:SetVerticalScroll(offset + distance)
  return distance
end

-- Anchors `menu` to `button` and sets its height: `height`, or the whole rows
-- that fit. `inset`: the border drawn around the menu on every side.
function DropdownPlacement.Place(menu, button, inset, rowHeight, height)
  local view = viewOf(button)
  local above, below = roomAround(view, button)
  local up = false
  if above then
    local extra = GAP + 2 * inset
    local scrolled = scrollPage(view, height + extra - below, above)
    above, below = above - scrolled, below + scrolled
    up = below - extra < height and above > below
    local room = (up and above or below) - extra
    height = math.max(rowHeight, math.min(height, math.floor(room / rowHeight) * rowHeight))
  end
  menu:ClearAllPoints()
  if up then
    menu:SetPoint("BOTTOMLEFT", button, "TOPLEFT", inset, GAP + inset)
  else
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", inset, -GAP - inset)
  end
  menu:SetHeight(height)
  if menu.UpdateScrollChildRect then
    menu:UpdateScrollChildRect()
  end
end

ns.MessengerWindowDropdownPlacement = DropdownPlacement
return DropdownPlacement
