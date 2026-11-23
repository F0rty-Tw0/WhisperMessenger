local ConversationSnapshot = require("WhisperMessenger.Model.ConversationSnapshot")

local SEND_FIELDS = {
  "conversationKey",
  "displayName",
  "battleTag",
  "channel",
  "bnetAccountID",
  "conversationID",
  "guid",
  "gameAccountName",
}

return function()
  local function test_send_payload_copies_contact_send_fields()
    local contact = {
      conversationKey = "bnet::7",
      displayName = "Thrall",
      battleTag = "Thrall#1234",
      channel = "BN",
      bnetAccountID = 7,
      conversationID = 3,
      guid = "Player-1",
      gameAccountName = "Thrall-Area52",
      unreadCount = 4,
    }

    local payload = ConversationSnapshot.SendPayload(contact, "hi")

    assert(payload.target == contact.displayName, "target is the display name")
    assert(payload.text == "hi", "text is passed through")
    for _, field in ipairs(SEND_FIELDS) do
      assert(payload[field] == contact[field], field .. " comes from the contact")
    end
    assert(payload.unreadCount == nil, "non-send contact fields stay out")
  end

  test_send_payload_copies_contact_send_fields()
end
