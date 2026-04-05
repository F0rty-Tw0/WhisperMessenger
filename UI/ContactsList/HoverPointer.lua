local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local HoverPointer = {}

local function frameParent(frame)
  if not frame then
    return nil
  end
  if frame.GetParent then
    return frame:GetParent()
  end
  return frame.parent
end

local function focusContainsFrame(focus, frame)
  local current = focus
  while current do
    if current == frame then
      return true
    end
    current = frameParent(current)
  end
  return false
end

function HoverPointer.isPointerOverFrame(frame)
  if not frame then
    return false
  end

  local getMouseFocus = _G.GetMouseFocus
  if type(getMouseFocus) == "function" then
    local ok, focus = pcall(getMouseFocus)
    if ok then
      return focusContainsFrame(focus, frame)
    end
  end

  return frame.IsMouseOver and frame:IsMouseOver() or false
end

function HoverPointer.isPointerInsideRowFrames(row)
  return HoverPointer.isPointerOverFrame(row)
    or HoverPointer.isPointerOverFrame(row and row.removeButton)
    or HoverPointer.isPointerOverFrame(row and row.pinButton)
end

function HoverPointer.effectiveActionHoverCount(row)
  local count = (row and row._wmActionHoverCount) or 0
  if count <= 0 then
    return 0
  end

  local overAction = HoverPointer.isPointerOverFrame(row and row.removeButton)
    or HoverPointer.isPointerOverFrame(row and row.pinButton)

  if overAction then
    return count
  end

  row._wmActionHoverCount = 0
  return 0
end

ns.ContactsListHoverPointer = HoverPointer
return HoverPointer
