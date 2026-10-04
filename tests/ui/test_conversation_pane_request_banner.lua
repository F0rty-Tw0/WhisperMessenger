local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local Theme = require("WhisperMessenger.UI.Theme")

-- Opening a message request shows a banner above the composer with Accept
-- and Delete, in the same slot as the AFK/DND banner.

local NOTICE = "Not a friend, guildmate or group member."

local function nativeButton(root, label)
  return FindUI.find(root, function(node)
    return node.frameType == "Button" and node.template == "UIPanelButtonTemplate" and node.text == label
  end)
end

local function build(nativeChrome)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(600, 420)
  local calls = { accepted = {}, deleted = {} }
  local pane = ConversationPane.Create(factory, parent, nil, nil, {
    hideEmptyHeader = nativeChrome,
    nativeChrome = nativeChrome,
    onAcceptRequest = function(contact)
      calls.accepted[#calls.accepted + 1] = contact
    end,
    onDeleteRequest = function(contact)
      calls.deleted[#calls.deleted + 1] = contact
    end,
  })
  return pane, calls
end

return function()
  Localization.Configure({ language = "enUS" })
  local request = { conversationKey = "wow::stranger", displayName = "Stranger", channel = "WOW", isRequest = true }
  local conversation = { messages = {} }

  -- test_request_shows_banner_with_notice
  local pane, calls = build(false)
  local baseHeight = pane.transcript.scrollFrame.height
  ConversationPane.Refresh(pane, request, conversation)
  local notice = FindUI.text(pane.frame, NOTICE)
  assert(notice ~= nil and notice.parent.shown == true, "request banner shows the notice")
  assert(pane.transcript.scrollFrame.height == baseHeight - 24, "transcript makes room for the banner")

  -- test_accept_and_delete_report_the_contact
  FindUI.click(FindUI.byLabel(pane.frame, "Accept"))
  FindUI.click(FindUI.byLabel(pane.frame, "Delete"))
  assert(calls.accepted[1] == request, "Accept reports the open contact")
  assert(calls.deleted[1] == request, "Delete reports the open contact")

  -- test_request_banner_replaces_the_afk_text
  ConversationPane.RefreshActiveStatus(pane, { text = "Away" })
  assert(pane.activeStatusBanner.shown == false, "AFK text hidden while the request banner shows")

  -- test_normal_contact_hides_the_banner
  ConversationPane.Refresh(pane, { conversationKey = "wow::friend", displayName = "Friend", channel = "WOW" }, conversation)
  assert(notice.parent.shown == false, "no banner for a normal whisper")
  assert(pane.transcript.scrollFrame.height == baseHeight, "transcript height restored")

  -- test_wrapped_notice_grows_the_strip_and_transcript_room
  -- At a big font the notice wraps beside the buttons; the strip grows to
  -- the wrapped text (plus 4px) and the transcript gives up that much.
  local bigPane = build(false)
  ConversationPane.Refresh(bigPane, request, conversation)
  local bigNotice = assert(FindUI.text(bigPane.frame, NOTICE), "request notice exists")
  local strip = bigNotice.parent
  local noticeHeight = 54
  bigNotice.GetStringHeight = function()
    return noticeHeight
  end
  ConversationPane.Relayout(bigPane, 600, 420)
  assert(strip.height == 58, "strip fits the wrapped notice, got " .. tostring(strip.height))
  assert(bigPane.transcript.scrollFrame.height == 420 - Theme.HeaderHeight() - 58, "transcript makes room for the tall strip")

  -- test_relayout_remeasures_the_notice
  noticeHeight = 36
  ConversationPane.Relayout(bigPane, 600, 420)
  assert(strip.height == 40, "strip follows the re-wrapped notice, got " .. tostring(strip.height))

  -- test_buttons_stay_vertically_centred_on_the_strip
  local deletePoint = assert(FindUI.byLabel(bigPane.frame, "Delete").point, "Delete is anchored")
  assert(deletePoint[1] == "RIGHT" and deletePoint[2] == strip, "Delete sits centred on the strip's right edge")
  local noticePoints = assert(bigNotice.points, "notice is anchored")
  assert(noticePoints[1][1] == "LEFT" and noticePoints[1][2] == strip, "notice is centred on the strip's left edge")

  -- test_short_notice_keeps_the_base_strip
  noticeHeight = 12
  ConversationPane.Relayout(bigPane, 600, 420)
  assert(strip.height == 24, "one-line notice keeps the base strip, got " .. tostring(strip.height))
  assert(bigPane.transcript.scrollFrame.height == 420 - Theme.HeaderHeight() - 24, "transcript reserves the base strip")

  -- test_native_hud_uses_blizzard_buttons
  local nativePane = build(true)
  ConversationPane.Refresh(nativePane, request, conversation)
  assert(nativeButton(nativePane.frame, "Accept") ~= nil, "HUD: Accept is a Blizzard button")
  assert(nativeButton(nativePane.frame, "Delete") ~= nil, "HUD: Delete is a Blizzard button")
end
