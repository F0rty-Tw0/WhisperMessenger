local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local DragReorder = ns.ContactsListDragReorder or require("WhisperMessenger.UI.ContactsList.DragReorder")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture

local DragController = {}

-- Creates drag-and-drop handlers for contact row reordering.
--
-- factory            : frame factory
-- controller         : table with .content and .scrollFrame
-- currentContactsRef : function() -> current contacts list
-- options            : { onReorder, rowHeight }
--
-- Returns: { handleDragStart, handleDragStop }
function DragController.Create(factory, controller, currentContactsRef, options)
  options = options or {}
  local rowH = options.rowHeight or Theme.LAYOUT.CONTACT_ROW_HEIGHT

  local dragState = {
    active = false,
    sourceIndex = nil,
    ghostFrame = nil,
    dropIndicator = nil,
  }

  local function createGhostFrame(sourceRow)
    if dragState.ghostFrame == nil then
      dragState.ghostFrame = factory.CreateFrame("Frame", nil, sourceRow.parent or controller.content)
      dragState.ghostFrame:SetSize(sourceRow:GetWidth(), sourceRow:GetHeight())
      if dragState.ghostFrame.SetFrameStrata then
        dragState.ghostFrame:SetFrameStrata("TOOLTIP")
      end
      dragState.ghostFrame.bg = dragState.ghostFrame:CreateTexture(nil, "BACKGROUND")
      dragState.ghostFrame.bg:SetAllPoints()
      applyColorTexture(dragState.ghostFrame.bg, Theme.COLORS.bg_contact_selected)
      if dragState.ghostFrame.SetAlpha then
        dragState.ghostFrame:SetAlpha(0.7)
      end
      dragState.ghostFrame.label = dragState.ghostFrame:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_name)
      dragState.ghostFrame.label:SetPoint("CENTER")
      dragState.ghostFrame.label:SetJustifyH("CENTER")
    end
    dragState.ghostFrame.label:SetText(sourceRow.item and sourceRow.item.displayName or "")
    return dragState.ghostFrame
  end

  local function createDropIndicator()
    if dragState.dropIndicator == nil then
      dragState.dropIndicator = factory.CreateFrame("Frame", nil, controller.content)
      dragState.dropIndicator:SetSize(controller.content:GetWidth(), 2)
      dragState.dropIndicator.bg = dragState.dropIndicator:CreateTexture(nil, "OVERLAY")
      dragState.dropIndicator.bg:SetAllPoints()
      applyColorTexture(dragState.dropIndicator.bg, Theme.COLORS.accent)
    end
    return dragState.dropIndicator
  end

  local function handleDragStart(sourceRow, sourceIndex)
    dragState.active = true
    dragState.sourceIndex = sourceIndex
    local ghost = createGhostFrame(sourceRow)
    ghost:SetPoint("CENTER", sourceRow, "CENTER", 0, 0)
    ghost:Show()

    local indicator = createDropIndicator()
    indicator:Hide()

    -- Attach an OnUpdate to track cursor position and update drop indicator
    if controller.content.SetScript then
      controller.content:SetScript("OnUpdate", function()
        if not dragState.active then
          return
        end

        local currentContacts = currentContactsRef()
        local cursorY = 0
        local scrollOffset = 0
        if type(_G.GetCursorPosition) == "function" then
          local _, cy = _G.GetCursorPosition()
          local scale = controller.content.GetEffectiveScale and controller.content:GetEffectiveScale() or 1
          local contentTop = 0
          if controller.content.GetTop then
            contentTop = controller.content:GetTop() or 0
          end
          cursorY = (contentTop - cy / scale)
        end
        if controller.scrollFrame and controller.scrollFrame.GetVerticalScroll then
          scrollOffset = controller.scrollFrame:GetVerticalScroll()
        end

        local totalRows = controller.content.visibleCount or #currentContacts
        local targetIndex = DragReorder.CursorToRowIndex(cursorY, scrollOffset, rowH, totalRows)
        local dropIndex = DragReorder.FindDropIndex(currentContacts, sourceIndex, targetIndex)

        -- Position drop indicator
        indicator:ClearAllPoints()
        indicator:SetPoint("TOPLEFT", controller.content, "TOPLEFT", 0, -((dropIndex - 1) * rowH))
        indicator:Show()

        -- Move ghost to follow cursor
        if ghost.ClearAllPoints then
          ghost:ClearAllPoints()
          ghost:SetPoint("TOPLEFT", controller.content, "TOPLEFT", 0, -((targetIndex - 1) * rowH))
        end
      end)
    end
  end

  local function handleDragStop(_sourceRow, sourceIndex)
    if not dragState.active then
      return
    end
    dragState.active = false

    local currentContacts = currentContactsRef()

    -- Calculate final drop position from cursor
    local cursorY = 0
    local scrollOffset = 0
    if type(_G.GetCursorPosition) == "function" then
      local _, cy = _G.GetCursorPosition()
      local scale = controller.content.GetEffectiveScale and controller.content:GetEffectiveScale() or 1
      local contentTop = 0
      if controller.content.GetTop then
        contentTop = controller.content:GetTop() or 0
      end
      cursorY = (contentTop - cy / scale)
    end
    if controller.scrollFrame and controller.scrollFrame.GetVerticalScroll then
      scrollOffset = controller.scrollFrame:GetVerticalScroll()
    end

    local totalRows = controller.content.visibleCount or #currentContacts
    local targetIndex = DragReorder.CursorToRowIndex(cursorY, scrollOffset, rowH, totalRows)
    local dropIndex = DragReorder.FindDropIndex(currentContacts, sourceIndex, targetIndex)

    -- Clean up visuals
    if dragState.ghostFrame then
      dragState.ghostFrame:Hide()
    end
    if dragState.dropIndicator then
      dragState.dropIndicator:Hide()
    end
    if controller.content.SetScript then
      controller.content:SetScript("OnUpdate", nil)
    end

    -- Fire reorder callback if position changed
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
