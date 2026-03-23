local DragReorder = require("WhisperMessenger.UI.ContactsList.DragReorder")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()

  -- test_find_drop_index_within_pinned_group
  do
    local items = {
      { conversationKey = "p1", pinned = true, sortOrder = 1 },
      { conversationKey = "p2", pinned = true, sortOrder = 2 },
      { conversationKey = "p3", pinned = true, sortOrder = 3 },
      { conversationKey = "u1", pinned = false, sortOrder = 1 },
      { conversationKey = "u2", pinned = false, sortOrder = 2 },
    }

    -- Dragging p1 (index 1) to position after p2 (index 2)
    local dropIndex = DragReorder.FindDropIndex(items, 1, 2)
    assert(dropIndex == 2, "should drop at index 2, got: " .. tostring(dropIndex))
  end

  -- test_find_drop_index_clamps_to_pinned_boundary
  do
    local items = {
      { conversationKey = "p1", pinned = true, sortOrder = 1 },
      { conversationKey = "p2", pinned = true, sortOrder = 2 },
      { conversationKey = "u1", pinned = false, sortOrder = 1 },
      { conversationKey = "u2", pinned = false, sortOrder = 2 },
    }

    -- Dragging p1 (pinned, index 1) toward index 4 (unpinned) → clamped to 2
    local dropIndex = DragReorder.FindDropIndex(items, 1, 4)
    assert(dropIndex == 2, "pinned drag should clamp to pinned boundary, got: " .. tostring(dropIndex))
  end

  -- test_find_drop_index_clamps_to_unpinned_boundary
  do
    local items = {
      { conversationKey = "p1", pinned = true, sortOrder = 1 },
      { conversationKey = "p2", pinned = true, sortOrder = 2 },
      { conversationKey = "u1", pinned = false, sortOrder = 1 },
      { conversationKey = "u2", pinned = false, sortOrder = 2 },
    }

    -- Dragging u2 (unpinned, index 4) toward index 1 (pinned) → clamped to 3
    local dropIndex = DragReorder.FindDropIndex(items, 4, 1)
    assert(dropIndex == 3, "unpinned drag should clamp to unpinned boundary, got: " .. tostring(dropIndex))
  end

  -- test_find_drop_index_same_position_returns_same
  do
    local items = {
      { conversationKey = "p1", pinned = true, sortOrder = 1 },
      { conversationKey = "u1", pinned = false, sortOrder = 1 },
    }

    local dropIndex = DragReorder.FindDropIndex(items, 1, 1)
    assert(dropIndex == 1, "same position should return same index, got: " .. tostring(dropIndex))
  end

  -- test_compute_new_orders_after_reorder
  do
    local items = {
      { conversationKey = "p1", pinned = true, sortOrder = 1 },
      { conversationKey = "p2", pinned = true, sortOrder = 2 },
      { conversationKey = "p3", pinned = true, sortOrder = 3 },
    }

    -- Move p3 (index 3) to index 1 (before p1)
    local orders = DragReorder.ComputeNewOrders(items, 3, 1)
    assert(orders["p3"] == 1, "p3 should become order 1, got: " .. tostring(orders["p3"]))
    assert(orders["p1"] == 2, "p1 should become order 2, got: " .. tostring(orders["p1"]))
    assert(orders["p2"] == 3, "p2 should become order 3, got: " .. tostring(orders["p2"]))
  end

  -- test_compute_new_orders_move_forward
  do
    local items = {
      { conversationKey = "u1", pinned = false, sortOrder = 1 },
      { conversationKey = "u2", pinned = false, sortOrder = 2 },
      { conversationKey = "u3", pinned = false, sortOrder = 3 },
    }

    -- Move u1 (index 1) to index 3 (after u3)
    local orders = DragReorder.ComputeNewOrders(items, 1, 3)
    assert(orders["u2"] == 1, "u2 should become order 1, got: " .. tostring(orders["u2"]))
    assert(orders["u3"] == 2, "u3 should become order 2, got: " .. tostring(orders["u3"]))
    assert(orders["u1"] == 3, "u1 should become order 3, got: " .. tostring(orders["u1"]))
  end

  -- test_cursor_to_row_index
  do
    local ROW_HEIGHT = 64
    -- cursor at y=32 (middle of first row) → index 1
    local idx = DragReorder.CursorToRowIndex(32, 0, ROW_HEIGHT, 5)
    assert(idx == 1, "middle of row 1 should be index 1, got: " .. tostring(idx))

    -- cursor at y=65 (start of second row) → index 2
    idx = DragReorder.CursorToRowIndex(65, 0, ROW_HEIGHT, 5)
    assert(idx == 2, "start of row 2 should be index 2, got: " .. tostring(idx))

    -- cursor beyond all rows → clamped to last
    idx = DragReorder.CursorToRowIndex(500, 0, ROW_HEIGHT, 5)
    assert(idx == 5, "beyond last row should clamp to 5, got: " .. tostring(idx))

    -- cursor above first row → clamped to 1
    idx = DragReorder.CursorToRowIndex(-10, 0, ROW_HEIGHT, 5)
    assert(idx == 1, "above first row should clamp to 1, got: " .. tostring(idx))
  end

  -- test_group_boundaries
  do
    local items = {
      { conversationKey = "p1", pinned = true },
      { conversationKey = "p2", pinned = true },
      { conversationKey = "u1", pinned = false },
      { conversationKey = "u2", pinned = false },
      { conversationKey = "u3", pinned = false },
    }

    local pinStart, pinEnd, unStart, unEnd = DragReorder.GroupBoundaries(items)
    assert(pinStart == 1, "pinned start should be 1, got: " .. tostring(pinStart))
    assert(pinEnd == 2, "pinned end should be 2, got: " .. tostring(pinEnd))
    assert(unStart == 3, "unpinned start should be 3, got: " .. tostring(unStart))
    assert(unEnd == 5, "unpinned end should be 5, got: " .. tostring(unEnd))
  end

  -- test_group_boundaries_no_pinned
  do
    local items = {
      { conversationKey = "u1", pinned = false },
      { conversationKey = "u2", pinned = false },
    }

    local pinStart, pinEnd, unStart, unEnd = DragReorder.GroupBoundaries(items)
    assert(pinStart == 0, "no pinned: pinStart should be 0, got: " .. tostring(pinStart))
    assert(pinEnd == 0, "no pinned: pinEnd should be 0, got: " .. tostring(pinEnd))
    assert(unStart == 1, "unpinned start should be 1, got: " .. tostring(unStart))
    assert(unEnd == 2, "unpinned end should be 2, got: " .. tostring(unEnd))
  end
end
