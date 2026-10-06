local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")

-- Only 1:1 whispers lend the contact's class to sender names: in group and
-- channel chats the contact's class is just the last sender's.
return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(600, 420)
  local pane = ConversationPane.Create(factory, parent, nil, nil)

  local function refresh(channel)
    local contact = { conversationKey = "key::" .. channel, channel = channel, displayName = "Jaina", classTag = "MAGE" }
    ConversationPane.Refresh(pane, contact, { messages = {} })
    return pane.transcript.senderFallbackClassTag
  end

  -- test_wow_whisper_sets_sender_fallback_class
  local wow = refresh("WOW")
  assert(wow == "MAGE", "WOW whisper should lend the contact class, got " .. tostring(wow))

  -- test_bnet_whisper_sets_sender_fallback_class
  local bn = refresh("BN")
  assert(bn == "MAGE", "BN whisper should lend the contact class, got " .. tostring(bn))

  -- test_group_chat_has_no_sender_fallback_class
  local party = refresh("PARTY")
  assert(party == nil, "party chat must not lend the contact class, got " .. tostring(party))

  -- test_channel_chat_has_no_sender_fallback_class
  local channel = refresh("CHANNEL")
  assert(channel == nil, "channel chat must not lend the contact class, got " .. tostring(channel))
end
