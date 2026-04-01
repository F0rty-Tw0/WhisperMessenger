local ContactsList = require("WhisperMessenger.UI.ContactsList")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local SlashCommands = require("WhisperMessenger.Core.SlashCommands")
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")

return function()
  local items = ContactsList.BuildItems({
    ["me::WOW::jaina-proudmoore"] = {
      displayName = "Jaina-Proudmoore",
      lastPreview = "Need assistance?",
      unreadCount = 2,
      lastActivityAt = 20,
      channel = "WOW",
    },
    ["me::WOW::anduin-stormrage"] = {
      displayName = "Anduin-Stormrage",
      lastPreview = "On my way.",
      unreadCount = 0,
      lastActivityAt = 10,
      channel = "WOW",
    },
  })

  assert(items[1].displayName == "Jaina-Proudmoore")
  assert(items[2].displayName == "Anduin-Stormrage")

  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

  local window = MessengerWindow.Create(factory, {
    title = "WhisperMessenger",
    contacts = items,
  })

  assert(window.frame.parent == _G.UIParent)
  assert(window.frame.point[1] == "CENTER")
  assert(window.frame.width == 920)
  assert(window.frame.height == 580)
  assert(window.frame.resizeBounds[1] == 640)
  assert(window.frame.resizeBounds[2] == 420)
  assert(window.frame.background ~= nil)
  assert(window.contactsPane ~= nil)
  assert(window.contentPane ~= nil)
  assert(window.contactsPane.point[1] == "TOPLEFT")
  assert(window.contactsPane.point[5] < 0)
  assert(window.contentPane.point[1] == "TOPLEFT")
  assert(window.contentPane.point[2] == window.contactsPane, "expected content pane to align with contacts pane")
  assert(window.contentPane.point[5] == 0, "expected content pane vertical offset to match contacts pane")
  assert(window.contactsDivider ~= nil)
  assert(window.contactsRightBorder ~= nil, "expected contacts right border texture")
  assert(
    window.contactsRightBorder.point[2] == window.contactsPane,
    "expected contacts right border anchored to contacts pane"
  )
  assert(
    window.contactsRightBorder.color[1] == Theme.COLORS.contacts_border_right[1],
    "expected contacts right border red channel to match contacts_border_right"
  )
  assert(window.contactsPaneBorder ~= nil, "expected contacts pane border set")
  assert(
    window.contactsPaneBorder.right == window.contactsRightBorder,
    "expected contactsRightBorder alias to point at contactsPaneBorder.right"
  )
  assert(
    window.contactsPaneBorder.top == window.contactsHeaderDivider,
    "expected contactsHeaderDivider alias to point at contactsPaneBorder.top"
  )
  assert(window.contactsPaneBorder.left ~= nil, "expected contacts pane left border")
  assert(window.contactsPaneBorder.bottom ~= nil, "expected contacts pane bottom border")
  local previousPreset = Theme.GetPreset and Theme.GetPreset() or nil
  if Theme.SetPreset then
    assert(Theme.SetPreset("plumber_warm"), "expected plumber_warm preset to apply")
    assert(type(window.refreshTheme) == "function", "expected window.refreshTheme function")
    window.refreshTheme()

    assert(
      window.contactsRightBorder.color[1] == Theme.COLORS.contacts_border_right[1],
      "expected contacts right border red channel to repaint with preset"
    )
    assert(
      window.contactsHeaderDivider.color[4] == Theme.COLORS.divider[4],
      "expected contacts top divider alpha to repaint with divider alpha"
    )
    local expectedTitleColor = Theme.COLORS.text_title or Theme.COLORS.text_primary
    assert(
      window.title.textColor[1] == expectedTitleColor[1],
      "expected title red channel to repaint with text_title/text_primary token"
    )
  end
  assert(window.headerDivider == nil, "expected chat top divider to be removed")
  assert(window.contactsHeaderDivider ~= nil, "expected contacts top divider texture")
  assert(
    window.contactsHeaderDivider.point[2] == window.contactsPane,
    "expected contacts top divider anchored to contacts pane"
  )
  assert(
    window.contactsHeaderDivider.color[1] == Theme.COLORS.divider[1],
    "expected contacts top divider red channel to match divider"
  )
  assert(
    window.contactsHeaderDivider.color[4] == Theme.COLORS.divider[4],
    "expected contacts top divider alpha to match divider"
  )
  assert(window.titleBarTopBorder ~= nil, "expected title bar top border texture")
  assert(
    window.titleBarTopBorder.color[1] == Theme.COLORS.divider[1],
    "expected title bar top border red channel to match divider"
  )
  assert(window.threadPane ~= nil)
  assert(window.composerPane ~= nil)
  assert(window.threadPane.height < window.contentPane.height)
  assert(window.composerDivider ~= nil, "expected composer divider texture")
  assert(
    window.composerDivider.point[2] == window.composerPane,
    "expected composer divider anchored against composer pane"
  )
  assert(
    window.composerDivider.color[1] == Theme.COLORS.divider[1],
    "expected composer divider red channel to match divider"
  )
  assert(window.threadPaneBorder == nil, "expected thread pane border set to be removed")
  assert(window.composerPaneBorder ~= nil, "expected composer pane border set")
  assert(
    window.composerPaneBorder.top == window.composerDivider,
    "expected composerDivider alias to point at composerPaneBorder.top"
  )
  assert(window.composerPaneBorder.left ~= nil, "expected composer pane left border")
  assert(window.composerPaneBorder.right ~= nil, "expected composer pane right border")
  assert(window.composerPaneBorder.bottom ~= nil, "expected composer pane bottom border")
  assert(window.titleBarBorder ~= nil, "expected title bar border set on window facade")
  assert(
    window.titleBarBorder.top == window.titleBarTopBorder,
    "expected titleBarTopBorder alias to point at titleBarBorder.top"
  )
  assert(window.composer.frame.parent == window.composerPane)
  assert(window.conversation.frame.parent == window.threadPane)
  assert(#window.contacts.rows == 2)
  assert(window.title.text == "WhisperMessenger")
  assert(window.title.point[1] == "TOPLEFT")
  assert(window.contacts.rows[1].title.point[1] == "TOPLEFT")
  assert(window.contacts.scrollBar ~= nil)
  assert(window.contacts.scrollBar.template == nil, "expected contacts scrollbar to avoid Blizzard scrollbar templates")
  assert(window.contacts.scrollBar.shown == false, "expected contacts scrollbar to stay hidden without overflow")
  assert(
    window.contacts.scrollFrame.width == window.contactsPane.width,
    "expected contacts viewport to use full width when scrollbar is hidden"
  )
  assert(window.conversation.header ~= nil)
  assert(window.conversation.transcript ~= nil)
  assert(window.conversation.transcript.width ~= nil)
  assert(window.conversation.transcript.height ~= nil)
  assert(window.conversation.transcript.scrollBar ~= nil)
  assert(
    window.conversation.transcript.scrollBar.template == nil,
    "expected transcript scrollbar to avoid Blizzard scrollbar templates"
  )
  assert(
    window.conversation.transcript.scrollBar.shown == false,
    "expected transcript scrollbar to stay hidden without overflow"
  )
  assert(
    window.conversation.transcript.scrollFrame.width == window.conversation.transcript.width,
    "expected transcript viewport to use full width when scrollbar is hidden"
  )
  assert(window.composer.input.point[1] == "BOTTOMLEFT")
  assert(window.composer.input.width ~= nil)
  assert(window.composer.sendButton.point[1] == "BOTTOMRIGHT")
  assert(window.composer.sendButton.width ~= nil)
  assert(window.composer.inputTopBorder == nil, "expected composer input top border to be removed")
  assert(window.composer.sendButton.sendBorderTop == nil, "expected send button top border tracking to be removed")
  assert(window.composer.inputBg.color ~= nil, "expected composer input background color")
  local expectedComposerInputBg = Theme.COLORS.bg_message_input or Theme.COLORS.bg_input
  assert(
    window.composer.inputBg.color[1] == expectedComposerInputBg[1],
    "composer input red channel should match bg_message_input/bg_input"
  )
  assert(
    window.composer.inputBg.color[2] == expectedComposerInputBg[2],
    "composer input green channel should match bg_message_input/bg_input"
  )
  assert(
    window.composer.inputBg.color[3] == expectedComposerInputBg[3],
    "composer input blue channel should match bg_message_input/bg_input"
  )
  assert(
    window.composer.inputBg.color[4] == expectedComposerInputBg[4],
    "composer input alpha should match bg_message_input/bg_input"
  )
  if Theme.SetPreset and previousPreset then
    Theme.SetPreset(previousPreset)
    if type(window.refreshTheme) == "function" then
      window.refreshTheme()
    end
  end

  _G.UIParent = savedUIParent

  _G.SlashCmdList = {}
  local toggled = false
  SlashCommands.Register({
    toggle = function()
      toggled = true
    end,
  })

  assert(_G.SLASH_WHISPERMESSENGER1 == "/wmsg")
  assert(_G.SLASH_WHISPERMESSENGER2 == "/whispermessenger")
  _G.SlashCmdList.WHISPERMESSENGER()
  assert(toggled == true)
end
