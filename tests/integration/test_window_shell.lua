local ContactsList = require("WhisperMessenger.UI.ContactsList")
local FindUI = require("tests.helpers.find_ui")
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
    settingsConfig = { windowScale = 1.25 },
  })

  assert(window.frame.parent == _G.UIParent)
  assert(window.frame.point[1] == "CENTER")
  assert(window.frame.width == Theme.WINDOW_WIDTH)
  assert(window.frame.height == Theme.WINDOW_HEIGHT)
  assert(window.frame:GetScale() == 1.25)
  local minWidth, minHeight = window.frame:GetResizeBounds()
  assert(minWidth == Theme.LAYOUT.WINDOW_MIN_WIDTH)
  assert(minHeight == Theme.LAYOUT.WINDOW_MIN_HEIGHT)
  assert(window.frame.background ~= nil)
  assert(window.contactsPane ~= nil)
  assert(window.contentPane ~= nil)
  -- contactsPane dual-anchors TOPLEFT + BOTTOMLEFT; verify the TOPLEFT
  -- entry keeps a negative y-offset (positioned below the top bar).
  local contactsTopLeft
  for _, p in ipairs(window.contactsPane.points or {}) do
    if p[1] == "TOPLEFT" then
      contactsTopLeft = p
      break
    end
  end
  assert(contactsTopLeft ~= nil, "expected contactsPane to have a TOPLEFT anchor")
  assert(contactsTopLeft[5] < 0, "expected contactsPane TOPLEFT y-offset below the top bar")
  -- contentPane dual-anchors TOPLEFT against contactsPane + BOTTOMRIGHT to Inset.
  local contentTopLeft
  for _, p in ipairs(window.contentPane.points or {}) do
    if p[1] == "TOPLEFT" then
      contentTopLeft = p
      break
    end
  end
  assert(contentTopLeft ~= nil, "expected contentPane to have a TOPLEFT anchor")
  assert(contentTopLeft[2] == window.contactsPane, "expected content pane to align with contacts pane")
  assert(contentTopLeft[5] == 0, "expected content pane vertical offset to match contacts pane")
  assert(window.contactsDivider ~= nil)
  local previousPreset = Theme.GetPreset and Theme.GetPreset() or nil
  if Theme.SetPreset then
    assert(Theme.SetPreset("plumber_warm"), "expected plumber_warm preset to apply")
    assert(type(window.refreshTheme) == "function", "expected window.refreshTheme function")
    window.refreshTheme()

    local expectedTitleColor = Theme.COLORS.text_title or Theme.COLORS.text_primary
    assert(window.title.textColor[1] == expectedTitleColor[1], "expected title red channel to repaint with text_title/text_primary token")
  end
  assert(window.headerDivider == nil, "expected chat top divider to be removed")
  assert(window.threadPane ~= nil)
  assert(window.composerPane ~= nil)
  assert(window.threadPane.height < window.contentPane.height)
  assert(window.threadPaneBorder == nil, "expected thread pane border set to be removed")
  assert(window.composer.frame.parent == window.composerPane)
  assert(window.conversation.frame.parent == window.threadPane)
  assert(#window.contacts.rows == 2)
  assert(window.title.text == "WhisperMessenger")
  -- Modern title is vertically centred on the title bar (TitleBarLayout).
  assert(window.title.point[1] == "CENTER", "expected modern title centred on the title bar")
  assert(window.contacts.rows[1].title.point[1] == "TOPLEFT")
  assert(window.contacts.scrollBar ~= nil)
  assert(window.contacts.scrollBar.template == nil, "expected contacts scrollbar to avoid Blizzard scrollbar templates")
  assert(window.contacts.scrollBar.shown == false, "expected contacts scrollbar to stay hidden without overflow")
  assert(window.contacts.scrollFrame.width == window.contactsPane.width, "expected contacts viewport to use full width when scrollbar is hidden")
  assert(window.conversation.header ~= nil)
  assert(window.conversation.transcript ~= nil)
  assert(window.conversation.transcript.width ~= nil)
  assert(window.conversation.transcript.height ~= nil)
  assert(window.conversation.transcript.scrollBar ~= nil)
  assert(window.conversation.transcript.scrollBar.template == nil, "expected transcript scrollbar to avoid Blizzard scrollbar templates")
  assert(window.conversation.transcript.scrollBar.shown == false, "expected transcript scrollbar to stay hidden without overflow")
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
  local composerInputFill = FindUI.ofType(window.composer.input, "Texture")[1]
  assert(composerInputFill.color ~= nil, "expected composer input background color")
  local expectedComposerInputBg = Theme.COLORS.bg_message_input or Theme.COLORS.bg_input
  for i = 1, 4 do
    assert(composerInputFill.color[i] == expectedComposerInputBg[i], "composer input fill channel " .. i .. " should match bg_message_input/bg_input")
  end
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
