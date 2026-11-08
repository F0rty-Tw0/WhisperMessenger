local PanelRegistry = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelRegistry")

local function withBadge(value, log, name)
  return {
    badge = function()
      return value
    end,
    onMarkAllRead = function()
      log[#log + 1] = "read:" .. name
    end,
    onUnreadChanged = function()
      log[#log + 1] = "unread:" .. name
    end,
  }
end

local function makeWindow()
  local window = { shown = {} }
  window.registerPanel = function()
    return true
  end
  window.setPanelTabShown = function(key, shown)
    window.shown[#window.shown + 1] = key .. ":" .. tostring(shown)
  end
  window.refreshPanelBadge = function() end
  return window
end

return function()
  local function setup(log)
    local active = { a = true, b = true }
    local registry = PanelRegistry.New({
      isActive = function(key)
        return active[key]
      end,
    })
    registry.register("a", withBadge(2, log, "a"))
    registry.register("b", withBadge(3, log, "b"))
    return registry, active
  end

  -- test_default_registry_treats_every_panel_as_active
  do
    local registry = PanelRegistry.New()
    registry.register("a", {})
    assert(registry.isActive("a") == true)
  end

  -- test_inactive_panel_leaves_badge_sum_and_first_badged_key
  do
    local registry, active = setup({})
    active.a = false
    assert(registry.badgeSum() == 3, "only b counts, got " .. registry.badgeSum())
    assert(registry.firstBadgedKey() == "b")
    active.a = true
    assert(registry.badgeSum() == 5, "counted again once allowed")
  end

  -- test_inactive_panel_gets_no_mark_all_read
  do
    local log = {}
    local registry, active = setup(log)
    active.a = false
    registry.bind(makeWindow())
    registry.markAllRead()
    assert(#log == 1 and log[1] == "read:b", "got " .. table.concat(log, ","))
  end

  -- test_inactive_panel_gets_no_unread_changed_call
  do
    local log, afters = {}, 0
    local savedTimer = _G.C_Timer
    _G.C_Timer = {
      After = function(_, fn)
        afters = afters + 1
        fn()
      end,
    }
    local registry, active = setup(log)
    active.a = false
    registry.observeUnread({})
    registry.observeUnread({ { channel = "WOW", conversationKey = "k", unreadCount = 1 } })
    assert(#log == 1 and log[1] == "unread:b", "got " .. table.concat(log, ","))
    -- Only an inactive panel listens: nothing is scheduled.
    local only = PanelRegistry.New({
      isActive = function()
        return false
      end,
    })
    only.register("a", withBadge(0, {}, "a"))
    afters = 0
    only.observeUnread({})
    only.observeUnread({ { channel = "WOW", conversationKey = "k", unreadCount = 1 } })
    _G.C_Timer = savedTimer
    assert(afters == 0, "no timer for an inactive listener")
  end

  -- test_bind_hides_the_tabs_of_inactive_panels (a panel unticked before the window exists)
  do
    local registry, active = setup({})
    active.a = false
    local window = makeWindow()
    registry.bind(window)
    assert(#window.shown == 1 and window.shown[1] == "a:false", "got " .. table.concat(window.shown, ","))
  end

  -- test_apply_active_follows_the_check_and_is_safe_before_bind
  do
    local registry, active = setup({})
    registry.applyActive("a")
    local window = makeWindow()
    registry.bind(window)
    active.a = false
    registry.applyActive("a")
    active.a = true
    registry.applyActive("a")
    assert(window.shown[1] == "a:false" and window.shown[2] == "a:true", "got " .. table.concat(window.shown, ","))
  end
end
