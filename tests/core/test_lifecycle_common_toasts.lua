local Common = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common")

-- Pop-up cards never stay up into a chat lock or restricted content.

local function newBootstrap(chatLocked)
  local spies = { cleared = 0 }
  local runtime = {
    store = { conversations = {} },
    isChatLocked = function()
      return chatLocked == true
    end,
    clearWhisperToasts = function()
      spies.cleared = spies.cleared + 1
    end,
  }
  return { runtime = runtime }, spies
end

return function()
  -- test_chat_lock_start_clears_whisper_cards
  do
    local Bootstrap, spies = newBootstrap(true)
    Common.notifyCompetitiveState(Bootstrap)
    assert(spies.cleared == 1, "a chat lock clears the cards, got " .. spies.cleared)
  end

  -- test_restricted_content_start_clears_whisper_cards
  do
    local Bootstrap, spies = newBootstrap(false)
    Bootstrap._inMythicContent = true
    Common.notifyCompetitiveState(Bootstrap)
    assert(spies.cleared == 1, "restricted content clears the cards, got " .. spies.cleared)
  end

  -- test_lock_lift_keeps_whisper_cards
  do
    local Bootstrap, spies = newBootstrap(false)
    Common.notifyCompetitiveState(Bootstrap)
    assert(spies.cleared == 0, "a lift clears nothing, got " .. spies.cleared)
  end
end
