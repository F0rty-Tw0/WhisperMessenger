local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")

local PAUSED = "Messages are paused."
local HINT = "To reply now, type /w and their name in the game's chat."

local function build(channel)
  local runtime = {
    activeConversationKey = "A",
    store = { conversations = { A = { messages = {} } } },
    sendStatusByConversation = {},
    availabilityByGUID = {},
    messagingNotice = PAUSED,
  }
  return runtime, { { conversationKey = "A", channel = channel } }
end

return function()
  -- test_paused_whisper_chat_points_to_the_games_chat
  -- Our composer is locked, but the game's own chat can still whisper.
  do
    local runtime, contacts = build("WOW")
    local state = ContactEnricher.BuildWindowSelectionState(runtime, contacts)
    assert(state.notice == PAUSED .. " " .. HINT, "whisper notice adds the /w hint, got: " .. tostring(state.notice))
  end

  -- test_paused_group_chat_keeps_the_plain_notice
  do
    local runtime, contacts = build("GUILD")
    local state = ContactEnricher.BuildWindowSelectionState(runtime, contacts)
    assert(state.notice == PAUSED, "group notice has no /w hint, got: " .. tostring(state.notice))
  end
end
