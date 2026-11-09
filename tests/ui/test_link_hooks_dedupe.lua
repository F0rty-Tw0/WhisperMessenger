local LinkHooksEnv = require("tests.helpers.link_hooks_env")

-- One shift-click fans out into several Blizzard insert paths in one frame:
-- on Retail ChatEdit_InsertLink calls ChatFrameUtil.InsertLink, and the click
-- also passes SetItemRef. Every one of them is post-hooked; only the first
-- insert of the frame may land in the composer.
return function()
  local env = LinkHooksEnv.New({
    globalInsertLink = function(text)
      return _G.ChatFrameUtil.InsertLink(text)
    end,
  })
  local input = env.NewInput()
  env.LinkHooks.RegisterInput(input)
  input.focused = true

  -- test_retail_wrapper_inserts_once
  do
    env.Reset()
    _G.ChatEdit_InsertLink("|Hitem:1|h[Item]|h")
    assert(#env.inserts == 1, "the Retail wrapper reaches both hooks but must insert once, got " .. #env.inserts)
  end

  -- test_shift_click_fanout_inserts_once
  do
    env.Reset()
    _G.ChatEdit_InsertLink("Gæmmer-Kazzak")
    _G.ChatFrameUtil.InsertLink("|Hplayer:Gæmmer-Kazzak:1:WHISPER|h[Gæmmer]|h")
    _G.SetItemRef("player:Gæmmer-Kazzak:1:WHISPER", "|cff3fc7eb|Hplayer:Gæmmer-Kazzak:1:WHISPER|hGæmmer|h|r")

    assert(#env.inserts == 1, "expected exactly one insert from the shift-click fanout, got " .. #env.inserts)
    assert(env.inserts[1] == "Gæmmer-Kazzak", "expected the plain name to land, got: " .. tostring(env.inserts[1]))
  end

  -- test_next_frame_inserts_again
  do
    env.frameTime = env.frameTime + 1
    _G.ChatFrameUtil.InsertLink("|Hitem:1|h[Item]|h")
    assert(#env.inserts == 2, "expected a second insert on the next frame, got " .. #env.inserts)
    assert(env.inserts[2] == "|Hitem:1|h[Item]|h", "expected the item link to land, got: " .. tostring(env.inserts[2]))
  end

  -- test_no_gettime_keeps_legacy_behavior
  do
    env.Reset()
    rawset(_G, "GetTime", nil)
    _G.ChatFrameUtil.InsertLink("Gæmmer-Kazzak")
    _G.ChatFrameUtil.InsertLink("|Hplayer:Gæmmer-Kazzak:1:WHISPER|h[Gæmmer]|h")
    assert(#env.inserts == 2, "without GetTime both same-frame inserts should land, got " .. #env.inserts)
  end

  env.Restore()
end
