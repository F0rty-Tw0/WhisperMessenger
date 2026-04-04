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
    ghostBg = nil,
    ghostLabel = nil,
    dropIndicator = nil,
    dropIndicatorBg = nil,
  }

  local function createGhostFrame(sourceRow)
    if dragState.ghostFrame == nil then
      local ghostParent = sourceRow.parent or controller.content
      local ghostFrame = factory.CreateFrame("Frame", nil, ghostParent)
      if ghostFrame == nil then
        return nil
      end
      dragState.ghostFrame = ghostFrame

      if ghostFrame.SetSize and sourceRow.GetWidth and sourceRow.GetHeight then
        ghostFrame:SetSize(sourceRow:GetWidth(), sourceRow:GetHeight())
      end
      if ghostFrame.SetFrameStrata then
        ghostFrame:SetFrameStrata("TOOLTIP")
      end

      if ghostFrame.CreateTexture then
        local ghostBg = ghostFrame:CreateTexture(nil, "BACKGROUND")
        dragState.ghostBg = ghostBg
        if ghostBg and ghostBg.SetAllPoints then
          ghostBg:SetAllPoints()
        end
        if ghostBg then
          applyColorTexture(ghostBg, Theme.COLORS.bg_contact_selected)
        end
      end

      if ghostFrame.SetAlpha then
        ghostFrame:SetAlpha(0.7)
      end

      if ghostFrame.CreateFontString then
        local ghostLabel = ghostFrame:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_name)
        dragState.ghostLabel = ghostLabel
        if ghostLabel and ghostLabel.SetPoint then
          ghostLabel:SetPoint("CENTER")
        end
        if ghostLabel and ghostLabel.SetJustifyH then
          ghostLabel:SetJustifyH("CENTER")
        end
      end
    end

    local ghostLabel = dragState.ghostLabel
    if ghostLabel and ghostLabel.SetText then
      ghostLabel:SetText(sourceRow.item and sourceRow.item.displayName or "")
    end
    return dragState.ghostFrame
  end

  local function createDropIndicator()
    if dragState.dropIndicator == nil then
      local indicator = factory.CreateFrame("Frame", nil, controller.content)
      if indicator == nil then
        return nil
      end
      dragState.dropIndicator = indicator

      if indicator.SetSize and controller.content.GetWidth then
        indicator:SetSize(controller.content:GetWidth(), 2)
      end
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

  local function handleDragStart(sourceRow, sourceIndex)
    dragState.active = true
    dragState.sourceIndex = sourceIndex
    local ghost = createGhostFrame(sourceRow)
    if ghost and ghost.SetPoint then
      ghost:SetPoint("CENTER", sourceRow, "CENTER", 0, 0)
    end
    if ghost and ghost.Show then
      ghost:Show()
    end

    local indicator = createDropIndicator()
    if indicator and indicator.Hide then
      indicator:Hide()
    end

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
        if indicator and indicator.ClearAllPoints then
          indicator:ClearAllPoints()
        end
        if indicator and indicator.SetPoint then
          indicator:SetPoint("TOPLEFT", controller.content, "TOPLEFT", 0, -((dropIndex - 1) * rowH))
        end
        if indicator and indicator.Show then
          indicator:Show()
        end

        -- Move ghost to follow cursor
        if ghost and ghost.ClearAllPoints then
          ghost:ClearAllPoints()
          if ghost.SetPoint then
            ghost:SetPoint("TOPLEFT", controller.content, "TOPLEFT", 0, -((targetIndex - 1) * rowH))
          end
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
    if dragState.ghostFrame and dragState.ghostFrame.Hide then
      dragState.ghostFrame:Hide()
    end
    if dragState.dropIndicator and dragState.dropIndicator.Hide then
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
