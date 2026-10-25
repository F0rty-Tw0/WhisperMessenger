local PanelRegistry = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelRegistry")
local ExternalPreview = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ExternalPreview")
local IconToggle = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconToggle")

local function noop() end

local function panel(badge)
  return { title = "Alerts", onShow = noop, badge = badge }
end

-- opts: visible, whisperUnread, competitive, showResult, noWidget (no widget
-- icon in use), previewHidden (the widget is not showing the preview). Returns the wrapped
-- toggle, the call log and the runtime so a test can register panels and a preview.
local function setup(opts)
  opts = opts or {}
  local calls = {}
  local visible = opts.visible == true
  local runtime = {
    panelRegistry = PanelRegistry.New(),
    externalPreview = ExternalPreview.New({
      now = function()
        return 1
      end,
    }),
  }
  local window = {
    registerPanel = function()
      return true
    end,
    showPanel = function(key)
      calls[#calls + 1] = "showPanel:" .. key
      return opts.showResult ~= false
    end,
  }
  runtime.window = window
  runtime.ensureWindow = function()
    calls[#calls + 1] = "ensure"
  end
  runtime.setWindowVisible = function(nextVisible)
    visible = nextVisible
    calls[#calls + 1] = "visible:" .. tostring(nextVisible)
  end
  runtime.isWindowVisible = function()
    return visible
  end
  runtime.isCompetitiveContent = function()
    return opts.competitive == true
  end
  runtime.isMythicLockdown = function()
    return false
  end
  runtime.panelRegistry.bind(window)
  local widget = {
    isExternalPreviewShown = function()
      return not opts.previewHidden and runtime.externalPreview.get() ~= nil
    end,
  }
  runtime.getWidgetIcon = function()
    return not opts.noWidget and widget or nil
  end

  local function toggle()
    calls[#calls + 1] = "toggle"
  end
  local function buildContacts()
    return { { channel = "WOW", unreadCount = opts.whisperUnread or 0 } }
  end
  return IconToggle.Wrap(runtime, toggle, buildContacts), calls, runtime
end

local function joined(calls)
  return table.concat(calls, ",")
end

return function()
  -- test_hidden_no_whispers_opens_the_preview_owners_panel
  do
    local onToggle, calls, runtime = setup()
    runtime.panelRegistry.register(
      "other",
      panel(function()
        return 5
      end)
    )
    runtime.panelRegistry.register("ca", panel())
    runtime.externalPreview.set("ca", { sender = "CA", text = "lead" }, false)
    onToggle()
    assert(joined(calls) == "ensure,visible:true,showPanel:ca", "preview owner's panel opens, toggle not called, got " .. joined(calls))
  end

  -- test_hidden_no_whispers_no_preview_opens_first_badged_panel
  do
    local onToggle, calls, runtime = setup()
    runtime.panelRegistry.register("quiet", panel())
    runtime.panelRegistry.register(
      "busy",
      panel(function()
        return 2
      end)
    )
    onToggle()
    assert(joined(calls) == "ensure,visible:true,showPanel:busy", "first badged panel opens, got " .. joined(calls))
  end

  -- test_unread_whisper_wins_over_preview
  do
    local onToggle, calls, runtime = setup({ whisperUnread = 1 })
    runtime.panelRegistry.register("ca", panel())
    runtime.externalPreview.set("ca", { sender = "CA", text = "lead" }, false)
    onToggle()
    assert(joined(calls) == "toggle", "unread whispers keep the plain toggle, got " .. joined(calls))
  end

  -- test_visible_window_toggles_even_with_preview
  do
    local onToggle, calls, runtime = setup({ visible = true })
    runtime.panelRegistry.register("ca", panel())
    runtime.externalPreview.set("ca", { sender = "CA", text = "lead" }, false)
    onToggle()
    assert(joined(calls) == "toggle", "visible window hides via toggle, got " .. joined(calls))
  end

  -- test_unregistered_preview_key_without_badges_toggles
  do
    local onToggle, calls, runtime = setup()
    runtime.panelRegistry.register("quiet", panel())
    runtime.externalPreview.set("ghost", { sender = "X", text = "lead" }, false)
    onToggle()
    assert(joined(calls) == "toggle", "no target panel falls back to toggle, got " .. joined(calls))
  end

  -- test_erroring_badge_is_ignored
  do
    local onToggle, calls, runtime = setup()
    runtime.panelRegistry.register(
      "broken",
      panel(function()
        error("boom")
      end)
    )
    runtime.panelRegistry.register(
      "busy",
      panel(function()
        return 1
      end)
    )
    onToggle()
    assert(joined(calls) == "ensure,visible:true,showPanel:busy", "erroring badge skipped, got " .. joined(calls))
  end

  -- test_refused_open_falls_back_to_toggle
  do
    local onToggle, calls, runtime = setup({ competitive = true })
    runtime.panelRegistry.register("ca", panel())
    runtime.externalPreview.set("ca", { sender = "CA", text = "lead" }, false)
    onToggle()
    assert(joined(calls) == "toggle", "a refused panel open keeps today's toggle, got " .. joined(calls))
  end

  -- test_failed_show_does_not_hide_the_opened_window
  do
    local onToggle, calls, runtime = setup({ showResult = false })
    runtime.panelRegistry.register("ca", panel())
    runtime.externalPreview.set("ca", { sender = "CA", text = "lead" }, false)
    onToggle()
    assert(joined(calls) == "ensure,visible:true,showPanel:ca", "window stays open when showPanel fails, got " .. joined(calls))
  end

  -- test_unregistered_preview_key_still_lets_a_badged_panel_open
  do
    local onToggle, calls, runtime = setup()
    runtime.panelRegistry.register(
      "busy",
      panel(function()
        return 2
      end)
    )
    runtime.externalPreview.set("ghost", { sender = "X", text = "lead" }, false)
    onToggle()
    assert(joined(calls) == "ensure,visible:true,showPanel:busy", "unregistered owner is skipped for the badged panel, got " .. joined(calls))
  end

  -- test_hidden_widget_preview_falls_through_to_the_first_badged_panel
  do
    local onToggle, calls, runtime = setup({ previewHidden = true })
    runtime.panelRegistry.register(
      "busy",
      panel(function()
        return 2
      end)
    )
    runtime.panelRegistry.register("ca", panel())
    runtime.externalPreview.set("ca", { sender = "CA", text = "lead" }, false)
    onToggle()
    assert(joined(calls) == "ensure,visible:true,showPanel:busy", "a preview not on screen does not pick the page, got " .. joined(calls))
  end

  -- test_preview_kept_without_a_widget_falls_through_to_the_first_badged_panel
  do
    local onToggle, calls, runtime = setup({ noWidget = true })
    runtime.panelRegistry.register(
      "busy",
      panel(function()
        return 2
      end)
    )
    runtime.panelRegistry.register("ca", panel())
    runtime.externalPreview.set("ca", { sender = "CA", text = "lead" }, false)
    onToggle()
    assert(joined(calls) == "ensure,visible:true,showPanel:busy", "no widget, no preview owner, got " .. joined(calls))
  end

  -- test_hidden_widget_preview_without_badges_toggles
  do
    local onToggle, calls, runtime = setup({ previewHidden = true })
    runtime.panelRegistry.register("ca", panel())
    runtime.externalPreview.set("ca", { sender = "CA", text = "lead" }, false)
    onToggle()
    assert(joined(calls) == "toggle", "nothing on screen and no badge keeps the plain toggle, got " .. joined(calls))
  end
end
