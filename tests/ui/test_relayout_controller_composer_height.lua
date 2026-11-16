local RelayoutController = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.RelayoutController")

local function build(overrides)
  overrides = overrides or {}
  local env = {
    layout = {},
    relayoutCalls = {},
    threads = {},
    refreshContactsCalls = 0,
    composer = { relayout = function() end },
  }
  local options = {
    layoutBuilder = {
      Relayout = function(layout, w, h, cw)
        env.relayoutCalls[#env.relayoutCalls + 1] = { w = w, h = h, cw = cw }
        local metrics = {
          contactsWidth = 260,
          contentWidth = 600,
          contentHeight = 600,
          threadHeight = 555 - (layout.composerHeight or 44),
        }
        if overrides.noContentHeight then
          metrics.contentHeight = nil
        end
        return metrics
      end,
    },
    layout = env.layout,
    setContactsWidth = function() end,
    composer = env.composer,
    conversation = {},
    conversationPane = {
      Relayout = function(_conversation, _width, threadHeight)
        env.threads[#env.threads + 1] = threadHeight
      end,
    },
    refreshContacts = function()
      env.refreshContactsCalls = env.refreshContactsCalls + 1
    end,
    getSelectedConversationKey = function()
      return nil
    end,
  }
  env.controller = RelayoutController.Create(options)
  return env
end

return function()
  -- test_resize_that_changes_the_rows_lays_out_twice
  do
    local env = build()
    env.composer.relayout = function()
      env.controller.setComposerHeight(56)
    end
    env.controller.relayoutWindow(900, 560, 260, false)
    assert(#env.relayoutCalls == 2, "second pass when the bar height changed")
    assert(env.layout.composerHeight == 56)
    assert(env.threads[#env.threads] == 555 - 56, "conversation gets the second pass's thread height")
  end

  -- test_resize_without_a_height_change_lays_out_once
  do
    local env = build()
    env.controller.relayoutWindow(900, 560, 260, false)
    assert(#env.relayoutCalls == 1)
  end

  -- test_composer_gets_a_third_of_the_content_height
  do
    local env = build()
    local seen
    env.composer.relayout = function(width, maxHeight)
      seen = { width, maxHeight }
    end
    env.controller.relayoutWindow(900, 560, 260, false)
    assert(seen[1] == 600 and seen[2] == 200)
  end

  -- test_no_content_height_means_no_cap
  do
    local env = build({ noContentHeight = true })
    local seen = { "unset" }
    env.composer.relayout = function(_width, maxHeight)
      seen = { maxHeight }
    end
    env.controller.relayoutWindow(900, 560, 260, false)
    assert(seen[1] == nil)
  end

  -- test_height_change_while_idle_relayouts_at_the_last_size
  do
    local env = build()
    env.controller.relayoutWindow(900, 560, 260, false)
    env.controller.setComposerHeight(68)
    local last = env.relayoutCalls[#env.relayoutCalls]
    assert(#env.relayoutCalls == 2)
    assert(last.w == 900 and last.h == 560 and last.cw == 260)
    assert(env.refreshContactsCalls == 0, "a height change never refreshes the contacts list")
  end

  -- test_same_height_does_nothing
  do
    local env = build()
    env.controller.relayoutWindow(900, 560, 260, false)
    env.controller.setComposerHeight(68)
    local n = #env.relayoutCalls
    env.controller.setComposerHeight(68)
    assert(#env.relayoutCalls == n)
  end

  -- test_height_before_the_first_relayout_is_only_stored
  do
    local env = build()
    env.controller.setComposerHeight(56)
    assert(env.layout.composerHeight == 56 and #env.relayoutCalls == 0)
  end

  -- test_a_failing_composer_relayout_rethrows_and_resets
  do
    local env = build()
    local failing = true
    env.composer.relayout = function()
      if failing then
        error("boom", 0)
      end
    end
    local ok, err = pcall(env.controller.relayoutWindow, 900, 560, 260, false)
    assert(not ok and err == "boom")
    failing = false
    local callsBefore = #env.relayoutCalls
    env.controller.setComposerHeight(80)
    assert(env.layout.composerHeight == 80 and #env.relayoutCalls > callsBefore, "not stuck in the running state")
  end
end
