local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactsList = ns.ContactsList or require("WhisperMessenger.UI.ContactsList")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local DragReorder = ns.ContactsListDragReorder or require("WhisperMessenger.UI.ContactsList.DragReorder")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture

local ContactsController = {}

-- Creates contact management state and wires infinite-scroll hooks.
--
-- factory       : frame factory
-- contactsView  : ScrollView created for the contacts pane
-- initialContacts : initial list of contacts (table)
-- options       : { onSelect, initialSelectedKey }
--
-- Returns:
--   { rows, refresh, loadMore, content, scrollFrame, scrollBar, view }
function ContactsController.Create(factory, contactsView, initialContacts, options)
  options = options or {}

  local currentContacts = initialContacts or {}
  local viewportH = contactsView.viewportHeight or 0
  local rowH = Theme.LAYOUT.CONTACT_ROW_HEIGHT
  local visibleCount = math.max(10, math.ceil(viewportH / rowH) + 1)

  local controller = {
    rows = {},
    content = contactsView.content,
    scrollFrame = contactsView.scrollFrame,
    scrollBar = contactsView.scrollBar,
    view = contactsView,
  }

  -- Drag-and-drop state
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
        local dropIndex = DragReorder.FindDropIndex(currentContacts, dragState.sourceIndex, targetIndex)

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

    -- Calculate final drop position from last known state
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

  local function refresh(nextContacts, selectedKey, resetPaging)
    if nextContacts ~= nil then
      currentContacts = nextContacts
      if resetPaging then
        visibleCount = 10
      end
    end

    controller.rows = ContactsList.Refresh(factory, controller.content, controller.rows, currentContacts, {
      selectedConversationKey = selectedKey,
      visibleCount = visibleCount,
      onSelect = function(item)
        if options.onSelect then
          options.onSelect(item)
        end
      end,
      onPin = function(item)
        if options.onPin then
          options.onPin(item)
        end
      end,
      onRemove = function(item)
        if options.onRemove then
          options.onRemove(item)
        end
      end,
      onDragStart = handleDragStart,
      onDragStop = handleDragStop,
    })
    ScrollView.Sync(contactsView)

    return controller.rows
  end

  local function loadMore()
    if not ContactsList.HasMore(controller.content) then
      return
    end
    visibleCount = visibleCount + 10
    -- selectedKey is managed by the facade; pass nil to keep current selection
    refresh(nil, nil)
  end

  local function fillViewport(newHeight)
    local needed = math.ceil(newHeight / rowH) + 1
    if needed > visibleCount then
      visibleCount = needed
      refresh(nil, nil)
    end
  end

  controller.refresh = refresh
  controller.loadMore = loadMore
  controller.fillViewport = fillViewport

  -- Infinite scroll: load more contacts when scrolling near the bottom
  local function checkLoadMore()
    local range = ScrollView.GetRange(contactsView)
    local offset = ScrollView.GetOffset(contactsView)
    if range > 0 and offset >= range - Theme.LAYOUT.CONTACT_ROW_HEIGHT then
      loadMore()
    end
  end

  if contactsView.scrollFrame and contactsView.scrollFrame.SetScript then
    local originalOnWheel = contactsView.scrollFrame:GetScript("OnMouseWheel")
    contactsView.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
      if originalOnWheel then
        originalOnWheel(self, delta)
      end
      checkLoadMore()
    end)
  end

  if contactsView.scrollBar and contactsView.scrollBar.SetScript then
    local originalOnValue = contactsView.scrollBar:GetScript("OnValueChanged")
    contactsView.scrollBar:SetScript("OnValueChanged", function(self, value)
      if originalOnValue then
        originalOnValue(self, value)
      end
      checkLoadMore()
    end)
  end

  return controller
end

ns.MessengerWindowContactsController = ContactsController

return ContactsController
