local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactsList = ns.ContactsList or require("WhisperMessenger.UI.ContactsList")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
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
