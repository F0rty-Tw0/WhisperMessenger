local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local DragReorder = {}

local math_floor = math.floor
local math_max = math.max
local math_min = math.min

--- Returns the boundaries of the pinned and unpinned groups.
-- Items are assumed to be pre-sorted (pinned first, then unpinned).
-- Returns pinStart, pinEnd, unpinnedStart, unpinnedEnd (1-based).
-- A group with no items returns 0, 0.
function DragReorder.GroupBoundaries(items)
  local pinStart, pinEnd = 0, 0
  local unStart, unEnd = 0, 0

  for i, item in ipairs(items) do
    if item.pinned then
      if pinStart == 0 then
        pinStart = i
      end
      pinEnd = i
    else
      if unStart == 0 then
        unStart = i
      end
      unEnd = i
    end
  end

  return pinStart, pinEnd, unStart, unEnd
end

--- Converts a cursor Y offset (relative to the list top) into a 1-based row index.
-- scrollOffset: current vertical scroll amount
-- rowHeight: height of each row
-- totalRows: total number of rows
function DragReorder.CursorToRowIndex(cursorY, scrollOffset, rowHeight, totalRows)
  local adjusted = cursorY + scrollOffset
  local raw = math_floor(adjusted / rowHeight) + 1
  return math_max(1, math_min(raw, totalRows))
end

--- Finds the valid drop index for a drag from sourceIndex to targetIndex,
-- clamped within the source item's group boundary.
function DragReorder.FindDropIndex(items, sourceIndex, targetIndex)
  local pinStart, pinEnd, unStart, unEnd = DragReorder.GroupBoundaries(items)
  local source = items[sourceIndex]

  if source.pinned then
    return math_max(pinStart, math_min(targetIndex, pinEnd))
  else
    return math_max(unStart, math_min(targetIndex, unEnd))
  end
end

--- Computes new sortOrder values after moving an item from sourceIndex to dropIndex.
-- Returns a table of { [conversationKey] = newSortOrder } for all affected items
-- within the same group.
function DragReorder.ComputeNewOrders(items, sourceIndex, dropIndex)
  local source = items[sourceIndex]
  local pinStart, pinEnd, unStart, unEnd = DragReorder.GroupBoundaries(items)

  local groupStart, groupEnd
  if source.pinned then
    groupStart, groupEnd = pinStart, pinEnd
  else
    groupStart, groupEnd = unStart, unEnd
  end

  -- Build ordered list of keys in the group, then move the source
  local keys = {}
  for i = groupStart, groupEnd do
    keys[#keys + 1] = items[i].conversationKey
  end

  -- Convert absolute indices to group-relative (1-based)
  local relSource = sourceIndex - groupStart + 1
  local relDrop = dropIndex - groupStart + 1

  -- Remove source from its current position
  local movedKey = table.remove(keys, relSource)
  -- Insert at the drop position
  table.insert(keys, relDrop, movedKey)

  -- Assign sequential sort orders
  local orders = {}
  for i, key in ipairs(keys) do
    orders[key] = i
  end

  return orders
end

ns.ContactsListDragReorder = DragReorder
return DragReorder
