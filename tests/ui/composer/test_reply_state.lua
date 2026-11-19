local ReplyState = require("WhisperMessenger.UI.Composer.ReplyState")

-- A conversation that folds into another hands its reply target over.
local function build(openKey)
  local open = { key = openKey }
  local changes = {}
  local state = ReplyState.Create(function()
    return open.key
  end, function(replyTo)
    changes[#changes + 1] = replyTo or false
  end)
  return state, open, changes
end

return function()
  local target = { wireId = "w1" }

  -- test_move_hands_the_target_to_the_new_key
  do
    local state, open = build("a")
    state.set("a", target)
    state.move("a", "b")
    assert(state.current() == nil, "the old key keeps no target")
    open.key = "b"
    assert(state.current() == target, "the new key replies to the same line")
  end

  -- test_move_keeps_the_receiving_key_target
  do
    local state = build("b")
    local own = { wireId = "w2" }
    state.set("b", own)
    state.set("a", target)
    state.move("a", "b")
    assert(state.current() == own, "the receiving conversation keeps its own target")
  end

  -- test_move_redraws_the_open_conversation
  do
    local state, open, changes = build("a")
    state.set("a", target)
    open.key = "b"
    local before = #changes
    state.move("a", "b")
    assert(#changes == before + 1 and changes[#changes] == target, "the open conversation shows the moved target")
  end
end
