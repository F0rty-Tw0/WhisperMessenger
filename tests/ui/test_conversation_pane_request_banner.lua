local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")

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

  -- test_native_hud_uses_blizzard_buttons
  local nativePane = build(true)
  ConversationPane.Refresh(nativePane, request, conversation)
  assert(nativeButton(nativePane.frame, "Accept") ~= nil, "HUD: Accept is a Blizzard button")
  assert(nativeButton(nativePane.frame, "Delete") ~= nil, "HUD: Delete is a Blizzard button")
end
