local DragController = require("WhisperMessenger.UI.MessengerWindow.DragController")
local FakeUI = require("tests.helpers.fake_ui")

local DIM_ALPHA = 0.4

local function makeEnv(factory)
  local content = factory.CreateFrame("Frame", nil, nil)
  content:SetSize(260, 400)
  content:Show()
  local controller = { content = content, scrollFrame = factory.CreateFrame("Frame", nil, nil) }
  local contacts = {
    { conversationKey = "me::WOW::alice", displayName = "Alice", classTag = "MAGE", pinned = true, sortOrder = 1 },
    { conversationKey = "me::WOW::bob", displayName = "Bob", classTag = "ROGUE", pinned = true, sortOrder = 2 },
  }
  local rows = {}
  for i, item in ipairs(contacts) do
    local row = factory.CreateFrame("Button", nil, content)
    row:SetSize(260, 44)
    row:SetFrameLevel(5)
    row.item = item
    row.classIcon = row:CreateTexture(nil, "ARTWORK")
    row.classIcon:SetTexture("Interface\\Icons\\ClassIcon_" .. item.classTag)
    row:Show()
    rows[i] = row
  end
  local handlers = DragController.Create(factory, controller, function()
    return contacts
  end, { rowHeight = 44 })
  return controller, contacts, rows, handlers
end

local function findGhost(content, rows)
  for _, child in ipairs(content.children) do
    local isRow = false
    for _, row in ipairs(rows) do
      if row == child then
        isRow = true
      end
    end
    if not isRow and child.shown == true then
      return child
    end
  end
  return nil
end

local function runOnUpdate(content)
  local onUpdate = content:GetScript("OnUpdate")
  assert(onUpdate ~= nil, "expected an OnUpdate while dragging")
  onUpdate(content, 0.016)
end

return function()
  local factory = FakeUI.NewFactory()

  -- test_drag_start_dims_source_row
  do
    local _controller, _contacts, rows, handlers = makeEnv(factory)
    handlers.handleDragStart(rows[1], 1)
    assert(rows[1]:GetAlpha() == DIM_ALPHA, "source row should dim to " .. DIM_ALPHA .. ", got " .. tostring(rows[1]:GetAlpha()))
    assert(rows[2]:GetAlpha() == 1, "other rows must stay at full alpha")
  end

  -- test_drop_restores_source_row_alpha
  do
    local _controller, _contacts, rows, handlers = makeEnv(factory)
    handlers.handleDragStart(rows[1], 1)
    handlers.handleDragStop(rows[1], 1)
    assert(rows[1]:GetAlpha() == 1, "source row alpha should restore on drop, got " .. tostring(rows[1]:GetAlpha()))
  end

  -- test_cancel_restores_alpha_hides_ghost_and_skips_reorder
  do
    local reordered = false
    local content = factory.CreateFrame("Frame", nil, nil)
    content:Show()
    local contacts = {
      { conversationKey = "a", displayName = "A", pinned = true },
      { conversationKey = "b", displayName = "B", pinned = true },
    }
    local row = factory.CreateFrame("Button", nil, content)
    row.item = contacts[1]
    row:Show()
    local handlers = DragController.Create(factory, { content = content }, function()
      return contacts
    end, {
      rowHeight = 44,
      onReorder = function()
        reordered = true
      end,
    })
    handlers.handleDragStart(row, 1)
    -- Cancel is reachable only through the content OnHide hook.
    for _, hook in ipairs(content._hookScripts.OnHide) do
      hook(content)
    end
    assert(row:GetAlpha() == 1, "cancel should restore source row alpha")
    assert(findGhost(content, { row }) == nil, "cancel should hide the ghost")
    assert(content:GetScript("OnUpdate") == nil, "cancel should clear the drag OnUpdate")
    handlers.handleDragStop(row, 1)
    assert(reordered == false, "a cancelled drag must not reorder on the late OnDragStop")
  end

  -- test_window_hide_cancels_drag
  do
    local controller, _contacts, rows, handlers = makeEnv(factory)
    handlers.handleDragStart(rows[1], 1)
    local hooks = controller.content._hookScripts and controller.content._hookScripts.OnHide
    assert(hooks and #hooks > 0, "drag controller should hook content OnHide")
    for _, hook in ipairs(hooks) do
      hook(controller.content)
    end
    assert(rows[1]:GetAlpha() == 1, "hiding the list should restore the source row")
    assert(controller.content:GetScript("OnUpdate") == nil, "hiding the list should end the drag")
  end

  -- test_refresh_rebinding_source_row_cancels_drag
  do
    local controller, contacts, rows, handlers = makeEnv(factory)
    handlers.handleDragStart(rows[1], 1)
    rows[1].item = contacts[2] -- list refresh reused the row for another contact
    runOnUpdate(controller.content)
    assert(rows[1]:GetAlpha() == 1, "rebinding the source row mid-drag should restore it")
    assert(controller.content:GetScript("OnUpdate") == nil, "rebinding the source row should end the drag")
  end

  -- test_source_row_hidden_cancels_drag
  do
    local controller, _contacts, rows, handlers = makeEnv(factory)
    handlers.handleDragStart(rows[1], 1)
    rows[1]:Hide()
    runOnUpdate(controller.content)
    assert(rows[1]:GetAlpha() == 1, "hiding the source row mid-drag should restore it")
  end

  -- test_ghost_is_opaque_card_above_rows
  do
    local controller, _contacts, rows, handlers = makeEnv(factory)
    handlers.handleDragStart(rows[1], 1)
    local ghost = findGhost(controller.content, rows)
    assert(ghost ~= nil, "expected a visible ghost card")
    assert(ghost.frameStrata == "TOOLTIP", "ghost must draw on its own strata above the window's rows")
    assert(ghost:GetAlpha() >= 0.9, "ghost card should be near-opaque, got " .. tostring(ghost:GetAlpha()))

    local opaqueBg = nil
    for _, child in ipairs(ghost.children) do
      if child.frameType == "Texture" and child.color and child.color[4] == 1 and child.allPoints then
        opaqueBg = child
        break
      end
    end
    assert(opaqueBg ~= nil, "ghost needs a fully opaque background texture")
  end

  -- test_ghost_shows_source_icon_and_name
  do
    local controller, _contacts, rows, handlers = makeEnv(factory)
    handlers.handleDragStart(rows[1], 1)
    local ghost = findGhost(controller.content, rows)
    local foundName, foundIcon = false, false
    local function scan(frame)
      for _, child in ipairs(frame.children or {}) do
        if child.frameType == "FontString" and child.text == "Alice" then
          foundName = true
        end
        if child.frameType == "Texture" and child.texturePath == "Interface\\Icons\\ClassIcon_MAGE" then
          foundIcon = true
        end
        scan(child)
      end
    end
    scan(ghost)
    assert(foundName, "ghost should show the dragged contact name")
    assert(foundIcon, "ghost should reuse the source row class icon")
  end

  -- test_ghost_spans_row_width
  do
    local controller, _contacts, rows, handlers = makeEnv(factory)
    handlers.handleDragStart(rows[1], 1)
    runOnUpdate(controller.content)
    local ghost = findGhost(controller.content, rows)
    local left, right = false, false
    for _, point in ipairs(ghost.points or {}) do
      if point[2] == rows[1] and point[1] == "TOPLEFT" and point[4] == 0 then
        left = true
      end
      if point[2] == rows[1] and point[1] == "TOPRIGHT" and point[4] == 0 then
        right = true
      end
    end
    assert(left and right, "ghost should span exactly the row's left/right edges")
  end
end
