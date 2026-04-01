local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local Composer = require("WhisperMessenger.UI.Composer")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")

local function colorsMatch(actual, expected)
  if type(actual) ~= "table" or type(expected) ~= "table" then
    return false
  end
  for i = 1, 4 do
    local a = actual[i] or (i == 4 and 1) or 0
    local e = expected[i] or (i == 4 and 1) or 0
    if a ~= e then
      return false
    end
  end
  return true
end

return function()
  local factory = FakeUI.NewFactory()
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  uiParent:SetSize(920, 580)

  local frame = factory.CreateFrame("Frame", "MainFrame", uiParent)
  frame:SetSize(920, 580)

  local previousPreset = Theme.GetPreset and Theme.GetPreset() or nil
  assert(Theme.SetPreset("wow_default"), "expected wow_default preset to apply for baseline")

  local layout = LayoutBuilder.Build(factory, frame, { width = 920, height = 580 }, {})
  assert(layout.contactsSearchBg ~= nil, "expected layout to expose contactsSearchBg")
  assert(layout.contactsRightBorder ~= nil, "expected layout to expose contactsRightBorder")
  assert(
    colorsMatch(layout.contactsSearchBg.color, Theme.COLORS.bg_search_input),
    "expected search input background to use bg_search_input token"
  )
  assert(
    colorsMatch(layout.contactsRightBorder.color, Theme.COLORS.contacts_border_right),
    "expected contacts right border to use contacts_border_right token"
  )
  assert(
    colorsMatch(layout.contactsSearchInput.textColor, Theme.COLORS.text_primary),
    "expected search input text to use text_primary token"
  )
  local clearLabel = layout.contactsSearchClearButton.children[1]
  assert(clearLabel ~= nil, "expected search clear button label")
  assert(
    colorsMatch(clearLabel.textColor, Theme.COLORS.text_secondary),
    "expected search clear label to use text_secondary token"
  )

  local composerParent = factory.CreateFrame("Frame", nil, uiParent)
  composerParent:SetSize(600, Theme.COMPOSER_HEIGHT)
  local composer = Composer.Create(factory, composerParent, { conversationKey = "wow::test" }, function() end)
  assert(
    colorsMatch(composer.inputBg.color, Theme.COLORS.bg_message_input),
    "expected composer input background to use bg_message_input token"
  )
  assert(composer.inputTopBorder == nil, "expected composer input top border to be removed")
  assert(composer.sendButton.sendBg ~= nil, "expected send button themed state tracking")
  assert(composer.sendButton.sendBorderTop == nil, "expected send button top border to be removed")
  assert(
    colorsMatch(composer.sendButton.sendBg.color, Theme.COLORS.send_button),
    "expected send button to use send_button token"
  )

  local transcriptParent = factory.CreateFrame("Frame", nil, uiParent)
  transcriptParent:SetSize(600, 400)
  local incomingBubble = BubbleFrame.CreateBubble(factory, transcriptParent, {
    direction = "in",
    kind = "user",
    text = "incoming message",
  }, {
    paneWidth = 600,
    showIcon = false,
  })
  assert(
    colorsMatch(incomingBubble.bgFills[1].color, Theme.COLORS.bg_bubble_in),
    "expected incoming bubble to use bg_bubble_in token"
  )

  assert(Theme.SetPreset("elvui_dark"), "expected elvui_dark preset to apply")
  layout.applyTheme(Theme)
  composer.refreshTheme()

  assert(
    colorsMatch(layout.contactsSearchBg.color, Theme.COLORS.bg_search_input),
    "expected search input background to update when preset changes"
  )
  assert(
    colorsMatch(composer.inputBg.color, Theme.COLORS.bg_message_input),
    "expected composer input background to update when preset changes"
  )
  assert(composer.inputTopBorder == nil, "expected composer input top border to stay removed after preset change")
  assert(
    colorsMatch(layout.contactsRightBorder.color, Theme.COLORS.contacts_border_right),
    "expected contacts right border to repaint on preset change"
  )
  assert(
    colorsMatch(composer.sendButton.sendBg.color, Theme.COLORS.send_button),
    "expected send button to repaint on preset change"
  )
  assert(composer.sendButton.sendBorderTop == nil, "expected send button top border to stay removed after preset change")
  assert(
    colorsMatch(layout.contactsSearchInput.textColor, Theme.COLORS.text_primary),
    "expected search input text color to update when preset changes"
  )
  assert(
    colorsMatch(clearLabel.textColor, Theme.COLORS.text_secondary),
    "expected search clear label color to update when preset changes"
  )

  local incomingBubbleAfterPreset = BubbleFrame.CreateBubble(factory, transcriptParent, {
    direction = "in",
    kind = "user",
    text = "incoming message after preset",
  }, {
    paneWidth = 600,
    showIcon = false,
  })
  assert(
    colorsMatch(incomingBubbleAfterPreset.bgFills[1].color, Theme.COLORS.bg_bubble_in),
    "expected incoming bubble to use updated bg_bubble_in token after preset change"
  )

  if Theme.SetPreset and previousPreset then
    assert(Theme.SetPreset(previousPreset), "expected to restore previous preset")
  else
    assert(Theme.SetPreset("wow_default"), "expected wow_default preset to restore")
  end

  print("  Input background and surface theming tests passed")
end
