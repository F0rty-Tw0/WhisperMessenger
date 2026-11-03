local PendingReaction = require("WhisperMessenger.Model.MessageReactions.PendingReaction")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")

return function()
  local savedTimer = _G.C_Timer
  local scheduled = {}
  _G.C_Timer = {
    After = function(delay, callback)
      table.insert(scheduled, { delay = delay, callback = callback })
    end,
  }

  -- test_visible_reaction_shows_pending_set_over_stored
  do
    local message = { reaction = { key = "heart" } }
    PendingReaction.BeginPending(message, 1, "set", "fire", "Me")
    assert(PendingReaction.VisibleReaction(message).key == "fire", "pending set must win over stored reaction")
  end

  -- test_visible_reaction_hides_stored_during_pending_remove
  do
    local message = { reaction = { key = "heart" } }
    PendingReaction.BeginPending(message, 1, "remove", "heart", "Me")
    assert(PendingReaction.VisibleReaction(message) == nil, "pending remove must hide the reaction")
  end

  -- test_clear_pending_needs_matching_token
  do
    local message = {}
    PendingReaction.BeginPending(message, 7, "set", "heart", "Me")
    assert(PendingReaction.ClearPending(message, 8) == false, "stale token must not clear")
    assert(PendingReaction.ClearPending(message, 7) == true and message._pendingReaction == nil, "own token must clear")
  end

  -- test_begin_pending_times_out_after_ttl
  do
    scheduled = {}
    local timedOut = 0
    local message = {}
    PendingReaction.BeginPending(message, 3, "set", "heart", "Me", function()
      timedOut = timedOut + 1
    end)
    assert(#scheduled == 1 and scheduled[1].delay == Protocol.PAIRING_TTL_SECONDS, "timeout must use pairing TTL")
    scheduled[1].callback()
    assert(timedOut == 1 and message._pendingReaction == nil, "timeout must clear and notify")
  end

  -- test_new_pending_token_increments_and_clear_transient_resets
  do
    local message = { _pendingReaction = { token = 1 } }
    local state = { store = { conversations = { c = { messages = { message } } } } }
    assert(PendingReaction.NewPendingToken(state) == 1 and PendingReaction.NewPendingToken(state) == 2, "tokens must count up")
    PendingReaction.ClearTransient(state)
    assert(message._pendingReaction == nil and state.messageReactionPendingSequence == nil, "transient state must reset")
  end

  _G.C_Timer = savedTimer
end
