local Store = require("WhisperMessenger.Model.ConversationStore")
local WhisperMessage = require("WhisperMessenger.Core.EventRouter.WhisperMessage")

-- The contact, message and conversation helpers every whisper branch of the
-- router shares.
local KEY = "wow::WOW::arthas-area52"

local function newState()
  return {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 10 }),
    availabilityByGUID = {},
    now = function()
      return 1000
    end,
  }
end

local function test_character_payload_resolves_contact_and_key()
  local contact, key = WhisperMessage.BuildConversationContact(newState(), { playerName = "Arthas-Area52", guid = "Player-1" })
  assert(contact ~= nil and key == KEY, "character whisper should resolve to its conversation key, got " .. tostring(key))
end

local function test_payload_without_a_name_has_no_contact()
  local contact, key = WhisperMessage.BuildConversationContact(newState(), { text = "hi" })
  assert(contact == nil and key == nil, "a payload without a sender must not build a contact")
end

local function test_battle_net_payload_needs_an_account_id()
  local contact, key = WhisperMessage.BuildConversationContact(newState(), { channel = "BN", playerName = "Jaina" })
  assert(contact == nil and key == nil, "a Battle.net payload without an account id must not build a contact")
end

local function test_build_message_keeps_direction_kind_and_line_id()
  local message = WhisperMessage.BuildMessage(newState(), { text = "hi", playerName = "Arthas-Area52", lineID = 7 }, nil, "in", "user", 1000)
  assert(message.id == "7" and message.direction == "in" and message.kind == "user", "message should carry its id, direction and kind")
  assert(message.text == "hi" and message.sentAt == 1000 and message.channel == "WOW", "message should carry text, time and channel")
end

local function test_is_open_prefers_the_window_answer()
  local state = newState()
  state.activeConversationKey = KEY
  assert(WhisperMessage.IsOpen(state, KEY) == true, "the selected key counts as open without a window answer")
  state.isConversationOpen = function()
    return false
  end
  assert(WhisperMessage.IsOpen(state, KEY) == false, "the window's answer wins over the selected key")
end

local function test_conversation_with_key_stamps_the_key()
  local state = newState()
  state.store.conversations[KEY] = { messages = {} }
  local conversation = WhisperMessage.ConversationWithKey(state, KEY)
  assert(conversation == state.store.conversations[KEY] and conversation.conversationKey == KEY, "stored conversation should come back stamped")
  assert(WhisperMessage.ConversationWithKey(state, "missing") == nil, "an unknown key has no conversation")
end

local function test_whisper_confirms_availability_until_the_proof_ages()
  local state = newState()
  WhisperMessage.ConfirmWhisperAvailability(state, { guid = "Player-1" }, nil)
  local confirmed = state.availabilityByGUID["Player-1"]
  assert(confirmed and confirmed.confirmedByWhisper == true and confirmed.confirmedAt == 1000, "a whisper should confirm availability")
  assert(WhisperMessage.IsWhisperProofFresh(confirmed, 1299) == true, "proof should hold inside five minutes")
  assert(WhisperMessage.IsWhisperProofFresh(confirmed, 1300) == false, "proof should lapse at five minutes")
end

return function()
  test_character_payload_resolves_contact_and_key()
  test_payload_without_a_name_has_no_contact()
  test_battle_net_payload_needs_an_account_id()
  test_build_message_keeps_direction_kind_and_line_id()
  test_is_open_prefers_the_window_answer()
  test_conversation_with_key_stamps_the_key()
  test_whisper_confirms_availability_until_the_proof_ages()
end
