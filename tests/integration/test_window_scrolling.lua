local ContactsList = require("WhisperMessenger.UI.ContactsList")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
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
  local initialContactVisibleCount = window.contacts.content.visibleCount
  assert(initialContactVisibleCount < #contacts, "expected contact paging before infinite scroll")
  assert(window.contacts.scrollFrame.scripts.OnMouseWheel ~= nil, "expected contacts mouse wheel scrolling")

  window.contacts.scrollBar:SetValue(0)
  assert(window.contacts.content.visibleCount == initialContactVisibleCount, "expected contacts load more to ignore top scrolling")

  window.contacts.scrollBar:SetValue(window.contacts.scrollFrame:GetVerticalScrollRange())
  assert(window.contacts.content.visibleCount > initialContactVisibleCount, "expected contacts load more to trigger near the bottom")

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
  assert(
    window.conversation.transcript.scrollBar.point[2] == window.conversation.transcript.scrollFrame,
    "expected transcript scrollbar to align with the transcript viewport"
  )
  assert(window.conversation.transcript.scrollBar.point[3] == "TOPRIGHT", "expected transcript scrollbar relative point")
  assert(window.conversation.transcript.scrollBar.point[4] == 0, "expected transcript scrollbar indicators to stay inside the window")
  assert(window.conversation.transcript.content ~= nil, "expected transcript scroll content")
  assert(
    window.conversation.transcript.scrollFrame.scrollChild == window.conversation.transcript.content,
    "expected transcript content to be wired as scroll child"
  )
  assert(window.conversation.transcript.scrollFrame:GetVerticalScrollRange() > 0, "expected overflowing transcript to be scrollable")
  local initialTranscriptVisibleCount = window.conversation.transcript._visibleCount
  assert(window.conversation.transcript.scrollFrame.scripts.OnMouseWheel ~= nil, "expected transcript mouse wheel scrolling")
  assert(
    window.conversation.transcript.content.width == window.conversation.transcript.scrollFrame.width,
    "expected transcript content width to track the viewport width on overflow"
  )
  assert(
    window.conversation.transcript.scrollFrame:GetVerticalScroll() == window.conversation.transcript.scrollFrame:GetVerticalScrollRange(),
    "expected transcript to snap to newest messages"
  )

  window.conversation.transcript.scrollBar:SetValue(0)
  assert(window.conversation.transcript._visibleCount > initialTranscriptVisibleCount, "expected transcript load more to trigger near the top")
  assert(window.conversation.transcript.scrollFrame:GetVerticalScroll() > 0, "expected transcript load more to preserve scroll position")

  for _ = 1, 200 do
    window.conversation.transcript.scrollFrame.scripts.OnMouseWheel(window.conversation.transcript.scrollFrame, 1)
  end
  assert(window.conversation.transcript.scrollFrame:GetVerticalScroll() == 0, "expected transcript scroll to clamp at the first message")

  for _ = 1, 200 do
    window.conversation.transcript.scrollFrame.scripts.OnMouseWheel(window.conversation.transcript.scrollFrame, -1)
  end
  assert(
    window.conversation.transcript.scrollFrame:GetVerticalScroll() == window.conversation.transcript.scrollFrame:GetVerticalScrollRange(),
    "expected transcript scroll to clamp at the newest message"
  )

  local transitionWindow = MessengerWindow.Create(factory, {
    title = "WhisperMessenger",
    contacts = contacts,
    selectedContact = selectedContact,
    conversation = {
      displayName = selectedContact.displayName,
      messages = buildMessages(1),
    },
  })
  assert(transitionWindow.conversation.transcript.scrollBar.shown == false, "expected transcript scrollbar to stay hidden before overflow")
  local fullTranscriptWidth = transitionWindow.conversation.transcript.scrollFrame.width
  assert(
    transitionWindow.conversation.transcript.text.width == fullTranscriptWidth,
    "expected transcript text width to match the viewport before overflow"
  )

  transitionWindow.refreshSelection({
    contacts = contacts,
    selectedContact = selectedContact,
    conversation = {
      displayName = selectedContact.displayName,
      messages = buildMessages(40),
    },
  })
  assert(transitionWindow.conversation.transcript.scrollBar.shown == true, "expected transcript scrollbar to appear after transcript overflow")
  assert(
    transitionWindow.conversation.transcript.scrollFrame.width < fullTranscriptWidth,
    "expected transcript viewport to shrink when overflow begins"
  )
  assert(
    transitionWindow.conversation.transcript.text.width == transitionWindow.conversation.transcript.scrollFrame.width,
    "expected transcript text width to shrink with the viewport when overflow begins"
  )

  transitionWindow.refreshSelection({
    contacts = contacts,
    selectedContact = selectedContact,
    conversation = {
      displayName = selectedContact.displayName,
      messages = buildMessages(1),
    },
  })
  assert(transitionWindow.conversation.transcript.scrollBar.shown == false, "expected transcript scrollbar to hide after transcript overflow clears")
  assert(
    transitionWindow.conversation.transcript.scrollFrame.width == fullTranscriptWidth,
    "expected transcript viewport to expand when overflow clears"
  )
  assert(
    transitionWindow.conversation.transcript.text.width == transitionWindow.conversation.transcript.scrollFrame.width,
    "expected transcript text width to expand with the viewport when overflow clears"
  )

  local scrollHost = factory.CreateFrame("Frame", nil, _G.UIParent)
  scrollHost:SetSize(120, 100)

  local exactFitView = ScrollView.Create(factory, scrollHost, {
    width = 120,
    height = 100,
    step = 24,
  })
  ScrollView.RefreshMetrics(exactFitView, 100, false)
  assert(exactFitView.scrollBar.shown == false, "expected scrollbar to stay hidden when content exactly fits the viewport")

  local resizedView = ScrollView.Create(factory, scrollHost, {
    width = 120,
    height = 100,
    step = 24,
  })
  resizedView.scrollFrame:SetSize(120, 50)
  ScrollView.RefreshMetrics(resizedView, 120, false)
  assert(resizedView.scrollFrame.height == 50, "expected refresh to preserve the live viewport height after resize")
  assert(resizedView.scrollBar.height == 50, "expected scrollbar height to track the live viewport height after resize")
  assert(resizedView.scrollFrame.width == 116, "expected overflowing viewport width to shrink after resize")
  assert(resizedView.content.width == resizedView.scrollFrame.width, "expected resized content width to match the viewport width")
  assert(resizedView.scrollBar.shown == true, "expected resized overflowing view to show the scrollbar")

  local lateInitView = ScrollView.Create(factory, scrollHost, {
    width = 120,
    height = 0,
    step = 24,
  })
  lateInitView.scrollFrame:SetSize(120, 80)
  ScrollView.RefreshMetrics(lateInitView, 160, false)
  assert(lateInitView.scrollFrame.height == 80, "expected refresh to recover from zero-height initialization")
  assert(lateInitView.scrollBar.height == 80, "expected zero-height recovery to size the scrollbar to the live viewport height")
  assert(lateInitView.scrollFrame.width == 116, "expected zero-height recovery to apply overflowing viewport width")
  assert(
    lateInitView.content.width == lateInitView.scrollFrame.width,
    "expected zero-height recovery to keep content width aligned with the viewport"
  )
  assert(lateInitView.scrollBar.shown == true, "expected zero-height recovery to show the scrollbar for overflowing content")

  _G.UIParent = savedUIParent
end
