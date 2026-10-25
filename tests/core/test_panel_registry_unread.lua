local FakeChatLines = require("tests.helpers.fake_chat_lines")
local PanelRegistry = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelRegistry")

local function noop() end

local function contact(key, n, channel)
  return { conversationKey = key, channel = channel or "WOW", unreadCount = n }
end

-- A fresh deferred timer: DeferAfter writes into the existing C_Timer table.
local function freshTimer()
  _G.C_Timer = {}
  FakeChatLines.DeferAfter()
end

local flush = FakeChatLines.FlushAfter

-- A registry with one counting panel; state.calls is the count.
local function counted()
  freshTimer()
  local registry = PanelRegistry.New()
  local state = { calls = 0 }
  registry.register("p", {
    onUnreadChanged = function()
      state.calls = state.calls + 1
    end,
  })
  return registry, state
end

return function()
  local savedTimer = rawget(_G, "C_Timer")

  -- test_first_observe_is_baseline_only
  do
    local registry, state = counted()
    registry.observeUnread({ contact("a", 1) })
    flush()
    assert(state.calls == 0, "got " .. state.calls)
  end

  -- test_unchanged_set_does_not_fire
  do
    local registry, state = counted()
    registry.observeUnread({ contact("a", 1) })
    registry.observeUnread({ contact("a", 1) })
    flush()
    assert(state.calls == 0, "got " .. state.calls)
  end

  -- test_count_change_fires_once_next_frame
  do
    local registry, state = counted()
    registry.observeUnread({ contact("a", 1) })
    registry.observeUnread({ contact("a", 2) })
    assert(state.calls == 0, "deferred")
    flush()
    assert(state.calls == 1, "got " .. state.calls)
  end

  -- test_two_changes_before_flush_fire_once
  do
    local registry, state = counted()
    registry.observeUnread({ contact("a", 1) })
    registry.observeUnread({ contact("a", 2) })
    registry.observeUnread({ contact("a", 3) })
    flush()
    assert(state.calls == 1, "got " .. state.calls)
  end

  -- test_key_going_to_zero_fires
  do
    local registry, state = counted()
    registry.observeUnread({ contact("a", 1), contact("b", 1) })
    registry.observeUnread({ contact("a", 0), contact("b", 1) })
    flush()
    assert(state.calls == 1, "got " .. state.calls)
  end

  -- test_swap_with_same_size_fires
  do
    local registry, state = counted()
    registry.observeUnread({ contact("a", 2) })
    registry.observeUnread({ contact("b", 2) })
    flush()
    assert(state.calls == 1, "got " .. state.calls)
  end

  -- test_bnet_and_group_changes_ignored
  do
    local registry, state = counted()
    registry.observeUnread({ contact("x", 1, "BN") })
    registry.observeUnread({ contact("x", 5, "BN"), contact("g", 3, "PARTY") })
    flush()
    assert(state.calls == 0, "got " .. state.calls)
  end

  -- test_no_callback_panel_schedules_nothing
  do
    local scheduled = 0
    _G.C_Timer = {
      After = function()
        scheduled = scheduled + 1
      end,
    }
    local registry = PanelRegistry.New()
    registry.register("p", { onShow = noop })
    registry.observeUnread({ contact("a", 1) })
    registry.observeUnread({ contact("a", 2) })
    assert(scheduled == 0, "got " .. scheduled)
  end

  -- test_throwing_callback_does_not_stop_next_and_returns_to_idle
  do
    freshTimer()
    local registry = PanelRegistry.New()
    local p2 = 0
    registry.register("p1", {
      onUnreadChanged = function()
        error("boom")
      end,
    })
    registry.register("p2", {
      onUnreadChanged = function()
        p2 = p2 + 1
      end,
    })
    registry.observeUnread({ contact("a", 1) })
    registry.observeUnread({ contact("a", 2) })
    flush()
    assert(p2 == 1, "first change, got " .. p2)
    registry.observeUnread({ contact("a", 3) })
    flush()
    assert(p2 == 2, "second change schedules again, got " .. p2)
  end

  -- test_panel_registered_while_pending_hears_the_call
  do
    local registry = counted()
    registry.observeUnread({ contact("a", 1) })
    registry.observeUnread({ contact("a", 2) })
    local p2 = 0
    registry.register("p2", {
      onUnreadChanged = function()
        p2 = p2 + 1
      end,
    })
    flush()
    assert(p2 == 1, "got " .. p2)
  end

  -- test_missing_c_timer_is_a_no_op
  do
    local registry, state = counted()
    _G.C_Timer = nil
    registry.observeUnread({ contact("a", 1) })
    registry.observeUnread({ contact("a", 2) })
    flush()
    assert(state.calls == 0, "got " .. state.calls)
  end

  -- test_order_is_registration_order
  do
    freshTimer()
    local registry = PanelRegistry.New()
    local log = {}
    for _, name in ipairs({ "p1", "p2" }) do
      registry.register(name, {
        onUnreadChanged = function()
          log[#log + 1] = name
        end,
      })
    end
    registry.observeUnread({ contact("a", 1) })
    registry.observeUnread({ contact("a", 2) })
    flush()
    assert(table.concat(log, ",") == "p1,p2", "got " .. table.concat(log, ","))
  end

  -- test_change_inside_callback_schedules_again
  do
    freshTimer()
    local registry = PanelRegistry.New()
    local calls = 0
    registry.register("p", {
      onUnreadChanged = function()
        calls = calls + 1
        registry.observeUnread({ contact("a", calls + 5) })
      end,
    })
    registry.observeUnread({ contact("a", 1) })
    registry.observeUnread({ contact("a", 2) })
    flush()
    flush()
    assert(calls == 2, "got " .. calls)
  end

  -- test_contact_without_a_key_is_ignored
  do
    local registry, state = counted()
    registry.observeUnread({ contact("a", 1) })
    registry.observeUnread({ contact("a", 1), contact(nil, 4) })
    flush()
    assert(state.calls == 0, "got " .. state.calls)
  end

  _G.C_Timer = savedTimer
end
