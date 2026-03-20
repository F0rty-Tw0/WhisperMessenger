local ContactsList = require("WhisperMessenger.UI.ContactsList")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")

local function buildContacts(count)
  local conversations = {}

  for index = 1, count do
    local name = string.format("Contact-%02d", index)
    local key = "me::WOW::" .. string.lower(name)
    conversations[key] = {
      displayName = name,
      lastPreview = "Preview " .. index,
      unreadCount = index % 3,
      lastActivityAt = count - index,
      channel = "WOW",
    }
  end

  return ContactsList.BuildItems(conversations)
end

local function buildMessages(count)
  local messages = {}

  for index = 1, count do
    table.insert(messages, {
      direction = index % 2 == 0 and "out" or "in",
      kind = "user",
      text = "Message " .. index,
    })
  end

  return messages
end

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

  -- Test 1: Relayout must not reset content height when content overflows
  local host = factory.CreateFrame("Frame", nil, _G.UIParent)
  host:SetSize(300, 544)

  local layout = LayoutBuilder.Build(factory, host, { width = 920, height = 580 })
  local cv = layout.contactsView

  -- Simulate contacts rendering that made content taller than viewport
  cv.content:SetSize(300, 960)
  local contentHeightBefore = cv.content:GetHeight()
  assert(contentHeightBefore == 960, "precondition: content taller than viewport")

  -- Relayout to a new height (window grows: 580 -> 700)
  LayoutBuilder.Relayout(layout, 920, 700)
  local newContactsH = 700 - 36 -- TOP_BAR_HEIGHT = 36

  assert(cv.scrollFrame:GetHeight() == newContactsH, "expected scrollFrame height to update to new viewport height")
  assert(
    cv.content:GetHeight() >= contentHeightBefore,
    "expected Relayout to NOT shrink content height below its pre-resize value, got "
      .. tostring(cv.content:GetHeight())
      .. " (was "
      .. tostring(contentHeightBefore)
      .. ")"
  )

  -- Relayout to a smaller height (window shrinks: 700 -> 450)
  LayoutBuilder.Relayout(layout, 920, 450)
  local smallContactsH = 450 - 36

  assert(cv.scrollFrame:GetHeight() == smallContactsH, "expected scrollFrame height to update after shrink")
  assert(
    cv.content:GetHeight() >= contentHeightBefore,
    "expected Relayout to NOT shrink content height after shrink, got "
      .. tostring(cv.content:GetHeight())
      .. " (was "
      .. tostring(contentHeightBefore)
      .. ")"
  )

  -- Test 2: Full window resize must not load all contacts
  local contacts = buildContacts(30)
  local messages = buildMessages(5)
  local selectedContact = contacts[1]

  local window = MessengerWindow.Create(factory, {
    title = "WhisperMessenger",
    contacts = contacts,
    selectedContact = selectedContact,
    conversation = {
      displayName = selectedContact.displayName,
      messages = messages,
    },
  })

  local initialVisibleCount = window.contacts.content.visibleCount
  assert(initialVisibleCount < #contacts, "expected paging: not all contacts visible initially")

  local scrollBefore = window.contacts.scrollFrame:GetVerticalScroll()
  assert(scrollBefore == 0, "expected scroll at top before resize")

  -- Simulate a resize by firing OnSizeChanged
  local frame = window.frame
  local onSizeChanged = frame.scripts and frame.scripts.OnSizeChanged
  assert(onSizeChanged ~= nil, "expected OnSizeChanged handler")

  frame:SetSize(920, 700)
  onSizeChanged(frame, 920, 700)

  local scrollAfter = window.contacts.scrollFrame:GetVerticalScroll()
  assert(scrollAfter == 0, "expected scroll to stay at top after resize, got " .. tostring(scrollAfter))

  local afterVisibleCount = window.contacts.content.visibleCount
  assert(
    afterVisibleCount < #contacts,
    "expected resize to NOT load all contacts, but got " .. tostring(afterVisibleCount) .. " of " .. tostring(#contacts)
  )

  _G.UIParent = savedUIParent
end
