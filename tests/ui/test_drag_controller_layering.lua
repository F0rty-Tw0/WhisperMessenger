local DragController = require("WhisperMessenger.UI.MessengerWindow.DragController")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local ROW_H = 44
local ROW_INSET_X = 2

-- pinnedCount pinned rows followed by unpinned ones; rows anchored like RowView.
local function makeEnv(factory, pinnedCount, total, onReorder)
  local content = factory.CreateFrame("Frame", nil, nil)
  content:SetSize(260, 400)
  content:Show()
  local contacts, rows = {}, {}
  for i = 1, total do
    local item = {
      conversationKey = "k" .. i,
      displayName = "C" .. i,
      classTag = "MAGE",
      pinned = i <= pinnedCount,
      sortOrder = i,
    }
    contacts[i] = item
    local row = factory.CreateFrame("Button", nil, content)
    row:SetSize(258, ROW_H)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", ROW_INSET_X, -((i - 1) * ROW_H))
    row.item = item
    row.classIcon = row:CreateTexture(nil, "ARTWORK")
    row:Show()
    rows[i] = row
  end
  local controller = { content = content, scrollFrame = factory.CreateFrame("Frame", nil, nil) }
  local handlers = DragController.Create(factory, controller, function()
    return contacts
  end, { rowHeight = ROW_H, onReorder = onReorder })
  return controller, rows, handlers
end

local function withCursorY(offsetY, fn)
  local saved = _G.GetCursorPosition
  rawset(_G, "GetCursorPosition", function()
    return 0, -offsetY -- fake content has no GetTop, so list top is y = 0
  end)
  fn()
  rawset(_G, "GetCursorPosition", saved)
end

local function runOnUpdate(content)
  content:GetScript("OnUpdate")(content, 0.016)
end

local function findPoint(frame, name)
  local found = nil
  for _, point in ipairs(frame.points or {}) do
    if point[1] == name then
      found = point -- last SetPoint wins (MoveTo clears and re-anchors)
    end
  end
  return assert(found, "expected a " .. name .. " anchor")
end

local function hostChildren(host)
  local ghost, indicator = nil, nil
  for _, child in ipairs(host.children) do
    if child.frameType == "Frame" and child.height == 2 then
      indicator = child
    elseif child.frameType == "Frame" then
      ghost = child
    end
  end
  return ghost, indicator
end

-- Content-space top edge of a frame anchored TOPLEFT to rows[sourceIndex].
local function contentTop(frame, sourceIndex)
  local point = findPoint(frame, "TOPLEFT")
  return point[5] - (sourceIndex - 1) * ROW_H, point
end

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  rawset(_G, "UIParent", uiParent)

  -- test_ghost_and_indicator_live_on_tooltip_strata_outside_window_hierarchy
  do
    uiParent.children = {}
    local controller, rows, handlers = makeEnv(factory, 3, 4)
    handlers.handleDragStart(rows[1], 1)
    withCursorY(2.5 * ROW_H, function()
      runOnUpdate(controller.content)
    end)
    local ghost, indicator = hostChildren(uiParent)
    assert(ghost ~= nil, "ghost should be parented to UIParent, not the scroll content")
    assert(ghost.frameStrata == "TOOLTIP", "ghost strata should be TOOLTIP, got " .. tostring(ghost.frameStrata))
    assert(indicator ~= nil, "drop indicator should be parented to UIParent")
    assert(indicator.frameStrata == "TOOLTIP", "indicator strata should be TOOLTIP")
    assert(indicator:GetFrameLevel() > ghost:GetFrameLevel(), "indicator draws above the ghost")
  end

  -- test_ghost_icon_falls_back_to_item_class_icon
  do
    uiParent.children = {}
    local _controller, rows, handlers = makeEnv(factory, 2, 2)
    handlers.handleDragStart(rows[1], 1) -- row texture unset: GetTexture() -> nil
    local ghost = hostChildren(uiParent)
    local want = Theme.ClassIcon("MAGE")
    local found = false
    local function scan(frame)
      for _, child in ipairs(frame.children or {}) do
        if child.frameType == "Texture" and child.texturePath == want then
          found = true
        end
        scan(child)
      end
    end
    scan(ghost)
    assert(found, "ghost icon should fall back to the contact's class icon")
  end

  -- test_indicator_sits_below_target_row_when_moving_down
  do
    uiParent.children = {}
    local controller, rows, handlers = makeEnv(factory, 4, 5)
    handlers.handleDragStart(rows[1], 1)
    withCursorY(2.5 * ROW_H, function()
      runOnUpdate(controller.content)
    end)
    local _, indicator = hostChildren(uiParent)
    assert(indicator and indicator.shown, "indicator shown for a real move")
    local top, left = contentTop(indicator, 1)
    -- item lands after row 3: boundary y = 3 * ROW_H, 2px line centred on it
    assert(top == -(3 * ROW_H - 1), "indicator should straddle the row 3/4 boundary, got " .. tostring(top))
    assert(left[2] == rows[1] and left[4] == 0, "indicator left edge should match the row inset")
    local right = findPoint(indicator, "TOPRIGHT")
    assert(right[2] == rows[1] and right[4] == 0, "indicator right edge should match the row")
  end

  -- test_indicator_sits_above_target_row_when_moving_up
  do
    uiParent.children = {}
    local controller, rows, handlers = makeEnv(factory, 4, 5)
    handlers.handleDragStart(rows[3], 3)
    withCursorY(0.5 * ROW_H, function()
      runOnUpdate(controller.content)
    end)
    local _, indicator = hostChildren(uiParent)
    local top = contentTop(indicator, 3)
    assert(top == 0, "indicator should sit on the list top edge, got " .. tostring(top))
  end

  -- test_indicator_hidden_when_drop_is_noop
  do
    uiParent.children = {}
    local controller, rows, handlers = makeEnv(factory, 4, 5)
    handlers.handleDragStart(rows[2], 2)
    withCursorY(1.5 * ROW_H, function()
      runOnUpdate(controller.content)
    end)
    local _, indicator = hostChildren(uiParent)
    assert(indicator == nil or not indicator.shown, "no indicator when the drop is the current position")
  end

  -- test_ghost_and_drop_clamped_to_pinned_group
  do
    uiParent.children = {}
    local orders = nil
    local controller, rows, handlers = makeEnv(factory, 2, 5, function(o)
      orders = o
    end)
    handlers.handleDragStart(rows[1], 1)
    withCursorY(4.5 * ROW_H, function()
      runOnUpdate(controller.content)
      local ghost, indicator = hostChildren(uiParent)
      local ghostTop = contentTop(ghost, 1)
      assert(ghostTop == -ROW_H, "ghost should stop at the last pinned row, got " .. tostring(ghostTop))
      assert(contentTop(indicator, 1) == -(2 * ROW_H - 1), "indicator stays at the pinned group's bottom")
      handlers.handleDragStop(rows[1], 1)
    end)
    assert(orders and orders.k1 == 2 and orders.k2 == 1, "drop over unpinned rows lands last in the pinned group")
    assert(orders.k3 == nil, "unpinned rows are never reordered by a pinned drag")
    assert(rows[1]:GetAlpha() == 1, "source row alpha restored after drop")
  end

  -- test_unpinned_drag_is_clamped_to_unpinned_group
  do
    uiParent.children = {}
    local controller, rows, handlers = makeEnv(factory, 2, 5)
    handlers.handleDragStart(rows[4], 4)
    withCursorY(0.5 * ROW_H, function()
      runOnUpdate(controller.content)
    end)
    local ghost = hostChildren(uiParent)
    local ghostTop = contentTop(ghost, 4)
    assert(ghostTop == -(2 * ROW_H), "unpinned ghost stops at the first unpinned row, got " .. tostring(ghostTop))
  end

  rawset(_G, "UIParent", savedUIParent)
end
