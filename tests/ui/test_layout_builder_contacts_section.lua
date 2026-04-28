local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local LayoutMetrics = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")
local ContactsSection = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ContactsSection")

return function()
  local factory = FakeUI.NewFactory()
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  uiParent:SetSize(920, 580)

  local frame = factory.CreateFrame("Frame", "MainFrame", uiParent)
  frame:SetSize(920, 580)

  local sizing = LayoutMetrics.CalculateRelayout({}, 920, 580, nil, Theme)
  local section = ContactsSection.Build(factory, frame, sizing, {
    theme = Theme,
  })

  assert(section.contactsPane ~= nil, "contactsPane should exist")
  assert(section.contactsPaneBorder ~= nil, "contactsPaneBorder should exist")
  assert(section.contactsHeaderDivider ~= nil, "contactsHeaderDivider should exist")
  assert(section.contactsSearch ~= nil, "contactsSearch result should exist")
  assert(section.contactsView ~= nil, "contactsView should exist")
  assert(section.contactsDivider ~= nil, "contactsDivider should exist")
  assert(section.contactsResizeHandle ~= nil, "contactsResizeHandle should exist")
  assert(section.contactsRightBorder ~= nil, "contactsRightBorder should exist")
  assert(
    section.contactsHandleWidth == LayoutMetrics.GetContactsResizeHandleWidth(Theme),
    "contactsHandleWidth should match layout metrics"
  )
  assert(section.contactsPane.parent == frame, "contactsPane should parent to frame when no inset is present")
  assert(section.contactsView.scrollFrame.point ~= nil, "contactsView.scrollFrame should be positioned")
end
