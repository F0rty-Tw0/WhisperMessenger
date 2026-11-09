local LinkHooksEnv = require("tests.helpers.link_hooks_env")

-- Any assignment from addon code to a Blizzard global or ChatFrameUtil field
-- taints that slot for the rest of the session, even when the value written
-- back is Blizzard's own function. Blizzard's Enter/send path then runs
-- tainted and SendChatMessage is blocked in an encounter. LinkHooks may only
-- post-hook through hooksecurefunc; it must never assign these slots.
return function()
  local env = LinkHooksEnv.New()
  local input = env.NewInput()
  env.LinkHooks.RegisterInput(input)

  -- Whatever hooksecurefunc put in the slots is the expected state from now on.
  local expectedGlobalInsertLink = env.globals.ChatEdit_InsertLink
  local expectedUtilInsertLink = env.chatFrameUtilBacking.InsertLink

  -- env.writes records every assignment to the watched Blizzard globals and
  -- ChatFrameUtil fields, including one that writes the same function back.
  local function assertUntouched(when)
    assert(#env.writes == 0, when .. ": LinkHooks assigned " .. table.concat(env.writes, ", "))
    assert(env.globals.ChatEdit_GetActiveWindow == env.originalGetActiveWindow, when .. ": ChatEdit_GetActiveWindow was replaced")
    assert(env.globals.ChatEdit_InsertLink == expectedGlobalInsertLink, when .. ": ChatEdit_InsertLink was replaced")
    assert(env.chatFrameUtilBacking.GetActiveWindow == env.originalGetActiveWindow, when .. ": ChatFrameUtil.GetActiveWindow was replaced")
    assert(env.chatFrameUtilBacking.InsertLink == expectedUtilInsertLink, when .. ": ChatFrameUtil.InsertLink was replaced")
  end

  -- test_register_input_assigns_no_blizzard_slot
  do
    assertUntouched("after RegisterInput")
  end

  -- test_focus_gained_assigns_no_blizzard_slot
  do
    input.focused = true
    env.Fire(input, "OnEditFocusGained")
    assertUntouched("while the composer is focused")
  end

  -- test_focus_lost_assigns_no_blizzard_slot
  do
    input.focused = false
    env.Fire(input, "OnEditFocusLost")
    assertUntouched("after the composer lost focus")
  end

  -- test_insert_links_are_post_hooked_through_hooksecurefunc
  do
    assert(env.hooks["ChatFrameUtil.InsertLink"] ~= nil, "ChatFrameUtil.InsertLink should be post-hooked")
    assert(env.hooks.ChatEdit_InsertLink ~= nil, "ChatEdit_InsertLink should be post-hooked")
    assert(env.hooks.ChatEdit_GetActiveWindow == nil, "ChatEdit_GetActiveWindow must not be hooked")
  end

  env.Restore()
end
