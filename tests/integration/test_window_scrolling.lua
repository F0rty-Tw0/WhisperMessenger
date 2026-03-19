local ContactsList = require("WhisperMessenger.UI.ContactsList")
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

  local contacts = buildContacts(20)
  local messages = buildMessages(40)
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

  assert(window.contacts.scrollFrame ~= nil, "expected contacts scroll frame")
  assert(window.contacts.scrollBar ~= nil, "expected contacts scrollbar")
  assert(window.contacts.scrollBar.shown == true, "expected contacts scrollbar to show on overflow")
  assert(window.contacts.scrollBar.point[1] == "TOPLEFT", "expected contacts scrollbar anchor")
  assert(window.contacts.scrollBar.point[2] == window.contacts.scrollFrame, "expected contacts scrollbar to align with the contacts viewport")
  assert(window.contacts.scrollBar.point[3] == "TOPRIGHT", "expected contacts scrollbar relative point")
  assert(window.contacts.scrollBar.point[4] == 0, "expected contacts scrollbar indicators to stay inside the window")
  assert(window.contacts.content ~= nil, "expected contacts scroll content")
  assert(window.contacts.scrollFrame.scrollChild == window.contacts.content, "expected contacts content to be wired as scroll child")
  assert(window.contacts.scrollFrame:GetVerticalScrollRange() > 0, "expected overflowing contacts to be scrollable")
  assert(window.contacts.rows[1].parent == window.contacts.content, "expected contact rows to be parented to scroll content")
  assert(window.contacts.scrollFrame.scripts.OnMouseWheel ~= nil, "expected contacts mouse wheel scrolling")

  for _ = 1, 20 do
    window.contacts.scrollFrame.scripts.OnMouseWheel(window.contacts.scrollFrame, -1)
  end
  assert(
    window.contacts.scrollFrame:GetVerticalScroll() == window.contacts.scrollFrame:GetVerticalScrollRange(),
    "expected contacts scroll to clamp at the last item"
  )

  for _ = 1, 20 do
    window.contacts.scrollFrame.scripts.OnMouseWheel(window.contacts.scrollFrame, 1)
  end
  assert(window.contacts.scrollFrame:GetVerticalScroll() == 0, "expected contacts scroll to clamp at the first item")

  assert(window.conversation.transcript.scrollFrame ~= nil, "expected transcript scroll frame")
  assert(window.conversation.transcript.scrollBar ~= nil, "expected transcript scrollbar")
  assert(window.conversation.transcript.scrollBar.shown == true, "expected transcript scrollbar to show on overflow")
  assert(window.conversation.transcript.scrollBar.point[1] == "TOPLEFT", "expected transcript scrollbar anchor")
  assert(window.conversation.transcript.scrollBar.point[2] == window.conversation.transcript.scrollFrame, "expected transcript scrollbar to align with the transcript viewport")
  assert(window.conversation.transcript.scrollBar.point[3] == "TOPRIGHT", "expected transcript scrollbar relative point")
  assert(window.conversation.transcript.scrollBar.point[4] == 0, "expected transcript scrollbar indicators to stay inside the window")
  assert(window.conversation.transcript.content ~= nil, "expected transcript scroll content")
  assert(window.conversation.transcript.scrollFrame.scrollChild == window.conversation.transcript.content, "expected transcript content to be wired as scroll child")
  assert(window.conversation.transcript.scrollFrame:GetVerticalScrollRange() > 0, "expected overflowing transcript to be scrollable")
  assert(window.conversation.transcript.scrollFrame.scripts.OnMouseWheel ~= nil, "expected transcript mouse wheel scrolling")
  assert(window.conversation.transcript.scrollFrame:GetVerticalScroll() == window.conversation.transcript.scrollFrame:GetVerticalScrollRange(), "expected transcript to snap to newest messages")

  for _ = 1, 20 do
    window.conversation.transcript.scrollFrame.scripts.OnMouseWheel(window.conversation.transcript.scrollFrame, 1)
  end
  assert(window.conversation.transcript.scrollFrame:GetVerticalScroll() == 0, "expected transcript scroll to clamp at the first message")

  for _ = 1, 20 do
    window.conversation.transcript.scrollFrame.scripts.OnMouseWheel(window.conversation.transcript.scrollFrame, -1)
  end
  assert(
    window.conversation.transcript.scrollFrame:GetVerticalScroll() == window.conversation.transcript.scrollFrame:GetVerticalScrollRange(),
    "expected transcript scroll to clamp at the newest message"
  )

  _G.UIParent = savedUIParent
end
