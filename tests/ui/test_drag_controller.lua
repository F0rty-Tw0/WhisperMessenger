local DragController = require("WhisperMessenger.UI.MessengerWindow.DragController")
local FakeUI = require("tests.helpers.fake_ui")

local function makeEnv(factory)
  local content = factory.CreateFrame("Frame", nil, nil)
  content:SetSize(260, 400)
  local scrollFrame = factory.CreateFrame("Frame", nil, nil)
  local controller = {
    content = content,
    scrollFrame = scrollFrame,
  }
  local contacts = {
    {
      conversationKey = "me::WOW::alice",
      displayName = "Alice",
      pinned = true,
      sortOrder = 1,
    },
    {
      conversationKey = "me::WOW::bob",
      displayName = "Bob",
      pinned = true,
      sortOrder = 2,
    },
  }
  return controller, contacts
end

return function()
  local factory = FakeUI.NewFactory()

  -- test_create_returns_handlers
  do
    local controller, contacts = makeEnv(factory)
    local handlers = DragController.Create(factory, controller, function()
      return contacts
    end, { rowHeight = 44 })
    assert(type(handlers) == "table", "expected Create to return a table")
    assert(type(handlers.handleDragStart) == "function", "expected handleDragStart to be a function")
    assert(type(handlers.handleDragStop) == "function", "expected handleDragStop to be a function")
  end

  -- test_drag_start_shows_ghost
  do
    local controller, contacts = makeEnv(factory)
    local handlers = DragController.Create(factory, controller, function()
      return contacts
    end, { rowHeight = 44 })

    local sourceRow = factory.CreateFrame("Frame", nil, controller.content)
    sourceRow:SetSize(260, 44)
    sourceRow.item = contacts[1]

    handlers.handleDragStart(sourceRow, 1)

    -- ghost frame is a child of content with alpha set (0.7)
    local ghost = nil
    for _, child in ipairs(controller.content.children) do
      if child.shown == true and child.alpha ~= nil then
        ghost = child
        break
      end
    end
    assert(ghost ~= nil, "expected a visible ghost frame after dragStart")
  end

  -- test_drag_stop_hides_ghost
  do
    local controller, contacts = makeEnv(factory)
    local handlers = DragController.Create(factory, controller, function()
      return contacts
    end, { rowHeight = 44 })

    local sourceRow = factory.CreateFrame("Frame", nil, controller.content)
    sourceRow:SetSize(260, 44)
    sourceRow.item = contacts[1]

    handlers.handleDragStart(sourceRow, 1)
    handlers.handleDragStop(sourceRow, 1)

    -- after stop, no ghost child should be visible (alpha marks ghost frames)
    local anyVisible = false
    for _, child in ipairs(controller.content.children) do
      if child.shown == true and child.alpha ~= nil then
        anyVisible = true
        break
      end
    end
    assert(anyVisible == false, "expected ghost frame to be hidden after dragStop")
  end

  -- test_drag_stop_fires_reorder
  do
    local reorderCalled = false
    local reorderOrders = nil

    local controller, contacts = makeEnv(factory)

    -- Override GetCursorPosition so cursor appears at row-2 Y position.
    -- content:GetTop() returns nil (no GetTop on fake frame), so contentTop = 0.
    -- scale = 1 (no GetEffectiveScale). cursorY = 0 - cy/1 = 0 - (-50) = 50.
    -- scrollOffset = 0. targetIndex = floor(50/44)+1 = 2. dropIndex = 2.
    local savedGetCursorPosition = _G.GetCursorPosition
    rawset(_G, "GetCursorPosition", function()
      return 0, -50
    end)

    local handlers = DragController.Create(factory, controller, function()
      return contacts
    end, {
      onReorder = function(orders)
        reorderCalled = true
        reorderOrders = orders
      end,
      rowHeight = 44,
    })

    local sourceRow = factory.CreateFrame("Frame", nil, controller.content)
    sourceRow:SetSize(260, 44)
    sourceRow.item = contacts[1]

    handlers.handleDragStart(sourceRow, 1)
    handlers.handleDragStop(sourceRow, 1)

    assert(reorderCalled == true, "expected onReorder to be called when drop position differs")
    assert(reorderOrders ~= nil, "expected reorderOrders to be non-nil")

    rawset(_G, "GetCursorPosition", savedGetCursorPosition)
  end
end
