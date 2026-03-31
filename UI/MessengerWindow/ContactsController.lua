local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactsList = ns.ContactsList or require("WhisperMessenger.UI.ContactsList")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local Navigation = ns.ScrollViewNavigation or require("WhisperMessenger.UI.ScrollView.Navigation")
local DragController = ns.MessengerWindowDragController or require("WhisperMessenger.UI.MessengerWindow.DragController")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")

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

  local dragHandlers = DragController.Create(factory, controller, function()
    return currentContacts
  end, {
    onReorder = options.onReorder,
    rowHeight = rowH,
  })
  local handleDragStart = dragHandlers.handleDragStart
  local handleDragStop = dragHandlers.handleDragStop

  local function refresh(nextContacts, selectedKey, resetPaging)
    if nextContacts ~= nil then
      currentContacts = nextContacts
    end
    if resetPaging then
      visibleCount = 10
      ScrollView.SetVerticalScroll(contactsView, 0)
    end

    controller.rows = ContactsList.Refresh(factory, controller.content, controller.rows, currentContacts, {
      selectedConversationKey = selectedKey,
      visibleCount = visibleCount,
      hideMessagePreview = type(options.getHideMessagePreview) == "function" and options.getHideMessagePreview()
        or options.hideMessagePreview,
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

  Navigation.InstallPostScrollHook(contactsView, checkLoadMore)

  return controller
end

ns.MessengerWindowContactsController = ContactsController

return ContactsController
