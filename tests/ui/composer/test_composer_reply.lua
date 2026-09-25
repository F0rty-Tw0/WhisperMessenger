local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

-- The composer remembers one reply target per conversation, attaches it to
-- the next send, and Escape cancels it.
local function build(acceptSend)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 50)
  local target = { conversationKey = "a", displayName = "Thrall", channel = "WOW" }
  local sent, changes, escapes = {}, {}, 0
  local composer = Composer.Create(
    factory,
    parent,
    target,
    function(payload)
      sent[#sent + 1] = payload
      return acceptSend ~= false
    end,
    function()
      escapes = escapes + 1
    end,
    nil,
    nil,
    {
      onReplyChanged = function(replyTo)
        changes[#changes + 1] = replyTo or false
      end,
    }
  )
  return composer, target, sent, changes, function()
    return escapes
  end
end

local function send(composer, text)
  composer.input:SetText(text)
  composer.input.scripts.OnEnterPressed(composer.input)
end

return function()
  local replyTo = { wireId = "w1", direction = "in", author = "Thrall", snippet = "you coming?" }

  -- test_reply_is_attached_to_the_next_send_then_cleared
  do
    local composer, _, sent, changes = build()
    composer.setReply("a", replyTo)
    assert(changes[#changes] == replyTo, "reply bar shows")
    send(composer, "on my way")
    assert(sent[1].replyTo == replyTo, "reply attached")
    assert(changes[#changes] == false, "reply bar hides after the send")
    send(composer, "again")
    assert(sent[2].replyTo == nil, "only the next message is a reply")
  end

  -- test_rejected_send_keeps_the_reply
  do
    local composer, _, _, changes = build(false)
    composer.setReply("a", replyTo)
    send(composer, "blocked")
    assert(changes[#changes] == replyTo, "still replying")
  end

  -- test_escape_cancels_the_reply_before_closing
  do
    local composer, _, _, changes, escapes = build()
    composer.setReply("a", replyTo)
    composer.input.scripts.OnEscapePressed(composer.input)
    assert(changes[#changes] == false and escapes() == 0, "first Escape only cancels the reply")
    composer.input.scripts.OnEscapePressed(composer.input)
    assert(escapes() == 1, "next Escape behaves as before")
  end

  -- test_reply_target_stays_with_its_conversation
  do
    local composer, target, sent, changes = build()
    composer.setReply("a", replyTo)
    target.conversationKey = "b"
    composer.loadDraft(nil)
    assert(changes[#changes] == false, "switching hides the bar")
    send(composer, "to b")
    assert(sent[1].replyTo == nil, "b is not replying")
    target.conversationKey = "a"
    composer.loadDraft(nil)
    assert(changes[#changes] == replyTo, "back to a: reply restored")
    composer.clearReply()
    assert(changes[#changes] == false, "close button clears it")
  end
end
