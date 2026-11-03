local Store = require("WhisperMessenger.Model.ConversationStore")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")

local KEY = "wow::WOW::arthas"

-- Removing a chat closes the game's temporary whisper tab for that player,
-- only when the "close the game's whisper tab" setting is on.
local function removeWith(settings)
  local savedFrames, savedClose = _G.CHAT_FRAMES, _G.FCF_Close
  local closed = {}
  _G.ChatFrame11 = { isTemporary = true, inUse = true, chatType = "WHISPER", chatTarget = "Arthas" }
  _G.CHAT_FRAMES = { "ChatFrame11" }
  _G.FCF_Close = function(frame)
    closed[#closed + 1] = frame
  end

  local runtime = { store = Store.New({ maxMessagesPerConversation = 10 }) }
  Store.EnsureConversation(runtime.store, KEY, { channel = "WOW", displayName = "Arthas" })
  local callbacks = WindowCallbacks.Create({
    runtime = runtime,
    accountState = { settings = settings },
    characterState = {},
  })
  local ok, err = pcall(callbacks.onRemove, { conversationKey = KEY })
  local frame = _G.ChatFrame11

  _G.CHAT_FRAMES, _G.FCF_Close, _G.ChatFrame11 = savedFrames, savedClose, nil
  assert(ok, tostring(err))
  assert(runtime.store.conversations[KEY] == nil, "the chat is removed either way")
  return closed, frame
end

return function()
  -- test_setting_off_leaves_game_whisper_tab_open
  do
    local closed = removeWith({})
    assert(#closed == 0, "off by default: game tab stays")
  end

  -- test_setting_on_closes_game_whisper_tab
  do
    local closed, frame = removeWith({ closeGameWhisperTab = true })
    assert(#closed == 1 and closed[1] == frame, "game tab closed with the chat")
  end
end
