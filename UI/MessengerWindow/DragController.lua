local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local DragReorder = ns.ContactsListDragReorder or require("WhisperMessenger.UI.ContactsList.DragReorder")
local DragGhost = ns.MessengerWindowDragGhost or require("WhisperMessenger.UI.MessengerWindow.DragGhost")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture

local math_max = math.max
local math_min = math.min

local DragController = {}

-- The dragged row stays in place, dimmed, while the ghost card follows the cursor.
local SOURCE_DIM_ALPHA = 0.4
local INDICATOR_HEIGHT = 2

-- Creates drag-and-drop handlers for contact row reordering.
--
-- factory            : frame factory
-- controller         : table with .content and .scrollFrame
-- currentContactsRef : function() -> current contacts list
-- options            : { onReorder, rowHeight }
--
-- Returns: { handleDragStart, handleDragStop, cancel }
function DragController.Create(factory, controller, currentContactsRef, options)
  options = options or {}
  local rowH = options.rowHeight or Theme.LAYOUT.CONTACT_ROW_HEIGHT
  local content = controller.content
  -- Ghost + indicator live outside the window so its strata flips can't bury them.
  local host = _G.UIParent or content

  local dragState = {
    active = false,
    sourceIndex = nil,
    sourceRow = nil,
    sourceKey = nil,
    sourceAlpha = nil,
    ghost = nil,
    dropIndicator = nil,
    dropIndicatorBg = nil,
  }

  local function createDropIndicator()
    if dragState.dropIndicator == nil then
      local indicator = factory.CreateFrame("Frame", nil, host)
      if indicator == nil then
        return nil
      end
      dragState.dropIndicator = indicator
      indicator:SetHeight(INDICATOR_HEIGHT)
      if indicator.CreateTexture then
        local indicatorBg = indicator:CreateTexture(nil, "OVERLAY")
        dragState.dropIndicatorBg = indicatorBg
        if indicatorBg and indicatorBg.SetAllPoints then
          indicatorBg:SetAllPoints()
        end
        if indicatorBg then
          applyColorTexture(indicatorBg, Theme.COLORS.accent)
        end
      end
    end
    return dragState.dropIndicator
  end

  -- Cursor Y below the list top (content units), before scroll adjustment.
  local function cursorOffsetY()
    if type(_G.GetCursorPosition) ~= "function" then
      return 0
    end
    local _, cy = _G.GetCursorPosition()
    local scale = content.GetEffectiveScale and content:GetEffectiveScale() or 1
    local contentTop = content.GetTop and content:GetTop() or 0
    return contentTop - cy / scale
  end

  local function scrollOffset()
    local scrollFrame = controller.scrollFrame
    if scrollFrame and scrollFrame.GetVerticalScroll then
      return scrollFrame:GetVerticalScroll()
    end
    return 0
  end

  local function computeDrop(sourceIndex)
    local currentContacts = currentContactsRef()
    local cursorY = cursorOffsetY()
    local totalRows = content.visibleCount or #currentContacts
    local targetIndex = DragReorder.CursorToRowIndex(cursorY, scrollOffset(), rowH, totalRows)
    local dropIndex = DragReorder.FindDropIndex(currentContacts, sourceIndex, targetIndex)
    return currentContacts, dropIndex, cursorY
  end

  -- Accent line on the row boundary where the item will land: below the target
  -- row when moving down, above it when moving up. Hidden for a no-op drop.
  local function placeDropIndicator(dropIndex)
    local indicator = dragState.dropIndicator
    if indicator == nil then
      return
    end
    local sourceIndex = dragState.sourceIndex
    if dropIndex == sourceIndex then
      indicator:Hide()
      return
    end
    local rowsAbove = dropIndex > sourceIndex and dropIndex or dropIndex - 1
    local lineTop = math_max(0, rowsAbove * rowH - INDICATOR_HEIGHT / 2)
    local offsetY = lineTop - (sourceIndex - 1) * rowH -- relative to the source row top
    indicator:ClearAllPoints()
    indicator:SetPoint("TOPLEFT", dragState.sourceRow, "TOPLEFT", 0, -offsetY)
    indicator:SetPoint("TOPRIGHT", dragState.sourceRow, "TOPRIGHT", 0, -offsetY)
    indicator:Show()
  end

  -- Centre the card on the cursor, kept inside the source item's group rows.
  local function placeGhost(currentContacts, cursorY)
    local sourceIndex = dragState.sourceIndex
    local groupStart, groupEnd = DragReorder.GroupRange(currentContacts, sourceIndex)
    local wanted = cursorY + scrollOffset() - rowH / 2
    local top = math_max((groupStart - 1) * rowH, math_min(wanted, (groupEnd - 1) * rowH))
    DragGhost.MoveTo(dragState.ghost, dragState.sourceRow, top - (sourceIndex - 1) * rowH)
  end

  -- Ends the drag visuals (drop and cancel share this); returns the source row.
  local function endDrag()
    dragState.active = false
    local sourceRow = dragState.sourceRow
    dragState.sourceRow = nil
    if sourceRow and sourceRow.SetAlpha then
      sourceRow:SetAlpha(dragState.sourceAlpha or 1)
    end
    if dragState.ghost then
      DragGhost.Hide(dragState.ghost)
    end
    if dragState.dropIndicator and dragState.dropIndicator.Hide then
      dragState.dropIndicator:Hide()
    end
    if content.SetScript then
      content:SetScript("OnUpdate", nil)
    end
    return sourceRow
  end

  local function cancel()
    if dragState.active then
      endDrag()
    end
  end

  -- Window/list hidden mid-drag: OnUpdate stops and OnDragStop may never fire.
  if content.HookScript then
    content:HookScript("OnHide", cancel)
  end

  -- A list refresh can hide the source row or rebind it to another contact.
  local function sourceRowLost()
    local row = dragState.sourceRow
    if row == nil or (row.IsVisible and not row:IsVisible()) then
      return true
    end
    return (row.item and row.item.conversationKey) ~= dragState.sourceKey
  end

  local function onDragUpdate()
    if not dragState.active then
      return
    end
    if sourceRowLost() then
      cancel()
      return
    end

    local currentContacts, dropIndex, cursorY = computeDrop(dragState.sourceIndex)
    placeDropIndicator(dropIndex)
    placeGhost(currentContacts, cursorY)
  end

  local function handleDragStart(sourceRow, sourceIndex)
    cancel()
    dragState.active = true
    dragState.sourceIndex = sourceIndex
    dragState.sourceRow = sourceRow
    dragState.sourceKey = sourceRow.item and sourceRow.item.conversationKey
    dragState.sourceAlpha = sourceRow.GetAlpha and sourceRow:GetAlpha() or 1
    if sourceRow.SetAlpha then
      sourceRow:SetAlpha(SOURCE_DIM_ALPHA)
    end

    dragState.ghost = dragState.ghost or DragGhost.Create(factory, host)
    DragGhost.MoveTo(dragState.ghost, sourceRow, 0)
    DragGhost.Show(dragState.ghost, sourceRow, content)

    -- Accent drop line stays visible over the card.
    local indicator = createDropIndicator()
    if indicator then
      DragGhost.PlaceOnTop(indicator, content)
      indicator:SetFrameLevel(dragState.ghost.frame:GetFrameLevel() + 2)
      indicator:Hide()
    end

    if content.SetScript then
      content:SetScript("OnUpdate", onDragUpdate)
    end
  end

  local function handleDragStop(_sourceRow, sourceIndex)
    if not dragState.active then
      return
    end
    local currentContacts, dropIndex = computeDrop(sourceIndex)
    endDrag()

    if dropIndex ~= sourceIndex and options.onReorder then
      local orders = DragReorder.ComputeNewOrders(currentContacts, sourceIndex, dropIndex)
      options.onReorder(orders)
    end
  end

  return {
    handleDragStart = handleDragStart,
    handleDragStop = handleDragStop,
  }
end

ns.MessengerWindowDragController = DragController

return DragController
