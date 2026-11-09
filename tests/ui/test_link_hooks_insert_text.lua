local LinkHooksEnv = require("tests.helpers.link_hooks_env")

-- LinkHooks.InsertText puts text into the composer the player is typing in and
-- reports whether the text really landed.
return function()
  local env = LinkHooksEnv.New()
  local input = env.NewInput()
  local keepOldText = false

  function input.GetText(self)
    if keepOldText then
      return self.text
    end
    return self.text .. table.concat(env.inserts)
  end
  function input.GetMaxBytes(self)
    return self.maxBytes
  end
  env.LinkHooks.RegisterInput(input)

  local itemLink = "|Hitem:1|h[Item]|h"
  local otherLink = "|Hitem:2|h[Other]|h"

  local function reset(focused)
    env.Reset()
    input.focused = focused
    input.shown = true
    input.text = ""
    input.maxBytes = nil
    keepOldText = false
    rawset(_G, "_wmSuspended", nil)
  end

  -- test_inserts_into_the_focused_input_and_returns_true
  do
    reset(true)
    local took = env.LinkHooks.InsertText(itemLink)
    assert(took == true, "a focused composer should take the text")
    assert(input:GetText() == itemLink, "expected the link in the input, got: " .. input:GetText())
  end

  -- test_refuses_when_no_input_has_focus
  do
    reset(false)
    local took = env.LinkHooks.InsertText(itemLink)
    assert(took == false, "an unfocused composer must refuse")
    assert(#env.inserts == 0, "nothing may be inserted without focus, got " .. #env.inserts)
  end

  -- test_refuses_when_suspended
  do
    reset(true)
    rawset(_G, "_wmSuspended", true)
    local took = env.LinkHooks.InsertText(itemLink)
    rawset(_G, "_wmSuspended", nil)
    assert(took == false, "a suspended addon must refuse")
    assert(#env.inserts == 0, "a suspended addon must not insert, got " .. #env.inserts)
  end

  -- test_refuses_text_that_would_pass_the_byte_cap
  do
    reset(true)
    input.maxBytes = 256
    input.text = string.rep("a", 250)
    local took = env.LinkHooks.InsertText(string.rep("b", 10))
    assert(took == false, "text past the byte cap must be refused")
    assert(#env.inserts == 0, "nothing may be inserted past the cap, got " .. #env.inserts)
  end

  -- test_false_when_the_input_put_the_old_text_back
  do
    reset(true)
    keepOldText = true
    local took = env.LinkHooks.InsertText(itemLink)
    assert(took == false, "an input that kept its old text did not take the link")
  end

  -- test_keeps_the_draft_and_inserts_at_the_cursor
  do
    reset(true)
    input.text = "hi "
    local took = env.LinkHooks.InsertText(itemLink)
    assert(took == true, "a draft in the input must not block the insert")
    assert(input:GetText() == "hi " .. itemLink, "expected the draft kept, got: " .. input:GetText())
  end

  -- test_second_insert_in_one_frame_returns_false
  do
    reset(true)
    local first = env.LinkHooks.InsertText(itemLink)
    local second = env.LinkHooks.InsertText(otherLink)
    assert(first == true, "the first insert in a frame should land")
    assert(second == false, "a second insert in the same frame must report false")
    assert(input:GetText() == itemLink, "only the first link may land, got: " .. input:GetText())
  end

  -- test_inserts_caller_text_verbatim_without_the_quest_rewrite
  do
    reset(true)
    local took = env.LinkHooks.InsertText("[Foo (12)]")
    assert(took == true, "plain text should land")
    assert(input:GetText() == "[Foo (12)]", "caller text must not be rewritten, got: " .. input:GetText())
  end

  -- test_takes_text_that_fills_the_byte_cap_exactly
  do
    reset(true)
    input.maxBytes = 256
    input.text = string.rep("a", 245)
    local took = env.LinkHooks.InsertText(string.rep("b", 10))
    assert(took == true, "255 bytes fit a 256-byte cap (one byte is the terminator)")
  end

  -- test_refuses_text_one_byte_past_the_byte_cap
  do
    reset(true)
    input.maxBytes = 256
    input.text = string.rep("a", 246)
    local took = env.LinkHooks.InsertText(string.rep("b", 10))
    assert(took == false, "256 bytes do not fit a 256-byte cap")
    assert(#env.inserts == 0, "nothing may be inserted past the cap, got " .. #env.inserts)
  end

  env.Restore()
end
