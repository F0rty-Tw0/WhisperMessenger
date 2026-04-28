local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local LayoutMetrics = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")
local ContentSection = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ContentSection")

return function()
  local factory = FakeUI.NewFactory()
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  uiParent:SetSize(920, 580)

  local frame = factory.CreateFrame("Frame", "MainFrame", uiParent)
  frame:SetSize(920, 580)

  local sizing = LayoutMetrics.CalculateRelayout({}, 920, 580, nil, Theme)

  local contactsPane = factory.CreateFrame("Frame", nil, frame)
  contactsPane:SetSize(sizing.contactsWidth, sizing.contactsHeight)
  contactsPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -Theme.TOP_BAR_HEIGHT)

  local section = ContentSection.Build(factory, frame, contactsPane, sizing, {
    theme = Theme,
  })

  assert(section.contentPane ~= nil, "contentPane should exist")
  assert(section.threadPane ~= nil, "threadPane should exist")
  assert(section.composerPane ~= nil, "composerPane should exist")
  assert(section.composerPaneBorder ~= nil, "composerPaneBorder should exist")
  assert(section.composerDivider ~= nil, "composerDivider should exist")

  assert(section.contentPane.parent == frame, "contentPane should parent to frame")
  assert(section.threadPane.parent == section.contentPane, "threadPane should parent to contentPane")
  assert(section.composerPane.parent == section.contentPane, "composerPane should parent to contentPane")

  assert(section.threadPane.point ~= nil, "threadPane should have anchoring")
  assert(section.composerPane.point ~= nil, "composerPane should have anchoring")
end
