local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local Theme = require("WhisperMessenger.UI.Theme")
local CloseGlyphButton = require("WhisperMessenger.UI.Shared.CloseGlyphButton")

-- While replying, the strip above the composer reads "Replying to <name>"
-- with the quoted snippet and a close button.
local function build(nativeChrome)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(600, 420)
  local pane = ConversationPane.Create(factory, parent, nil, nil, { hideEmptyHeader = nativeChrome, nativeChrome = nativeChrome })
  return pane
end

local function replyLabel(pane)
  return FindUI.find(pane.frame, function(node)
    return node.frameType == "FontString" and type(node.text) == "string" and string.find(node.text, "Replying to", 1, true) ~= nil
  end)
end

return function()
  Localization.Configure({ language = "enUS" })
  local contact = { conversationKey = "wow::thrall", displayName = "Thrall", channel = "WOW" }
  local replyTo = { wireId = "w1", direction = "in", author = "Thrall", snippet = "you coming?" }

  -- test_reply_shows_the_strip_and_shrinks_the_transcript
  local pane = build(false)
  ConversationPane.Refresh(pane, contact, { messages = {} })
  local baseHeight = pane.transcript.scrollFrame.height
  local cancelled = 0
  ConversationPane.SetReply(pane, replyTo, function()
    cancelled = cancelled + 1
  end)
  local label = replyLabel(pane)
  assert(label ~= nil and label.parent.shown == true, "reply strip shown")
  assert(string.find(label.text, "Thrall", 1, true) and string.find(label.text, "you coming?", 1, true), label.text)
  assert(pane.transcript.scrollFrame.height == baseHeight - 24, "transcript makes room")

  -- test_strip_lines_up_with_the_composer_edges
  local gutter = Theme.LAYOUT.COMPOSER_GUTTER
  local left, right = label.parent.points[1], label.parent.points[2]
  assert(left[4] == gutter and right[4] == -gutter, "strip inset matches the composer gutter")

  -- test_close_glyph_turns_red_on_hover_like_the_widget_preview
  local closeButton = FindUI.byLabel(label.parent, "X")
  local closeLabel = closeButton.label
  closeButton.scripts.OnEnter(closeButton)
  assert(closeLabel.textColor[1] == CloseGlyphButton.DANGER_HOVER[1], "red on hover")
  assert(#FindUI.ofType(closeButton, "Texture") == 0, "no hover box behind the glyph")
  closeButton.scripts.OnLeave(closeButton)
  assert(closeLabel.textColor[1] == Theme.COLORS.text_secondary[1], "neutral at rest")

  -- test_close_button_cancels
  FindUI.click(closeButton)
  assert(cancelled == 1, "close cancels the reply")

  -- test_afk_text_yields_to_the_reply
  ConversationPane.RefreshActiveStatus(pane, { text = "Away" })
  assert(pane.activeStatusBanner.shown == false, "AFK text hidden while replying")

  -- test_own_message_reads_you
  ConversationPane.SetReply(pane, { direction = "out", snippet = "mine" }, function() end)
  assert(string.find(replyLabel(pane).text, "Replying to You", 1, true), replyLabel(pane).text)

  -- test_clearing_restores_the_transcript
  ConversationPane.SetReply(pane, nil)
  assert(label.parent.shown == false, "strip hidden")
  assert(pane.activeStatusBanner.shown == true, "AFK text back")
  ConversationPane.RefreshActiveStatus(pane, nil)
  assert(pane.transcript.scrollFrame.height == baseHeight, "height restored")

  -- test_native_chrome_uses_the_blizzard_close_button
  local native = build(true)
  ConversationPane.Refresh(native, contact, { messages = {} })
  ConversationPane.SetReply(native, replyTo, function() end)
  local close = FindUI.find(native.frame, function(node)
    return node.template == "UIPanelCloseButton"
  end)
  assert(close ~= nil, "native close button")
end
