local Store = require("WhisperMessenger.Model.ConversationStore")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")
local PanelRegistry = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelRegistry")
local ExternalPreview = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ExternalPreview")
local IconSurfaces = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.IconSurfaces")

-- A runtime wired like the real one: a registry, the external preview slot,
-- and icon surfaces that read badge() on every update.
local function setup()
  local log = {}
  local icon = { total = nil, pulse = nil, previews = 0 }
  function icon.setUnreadCount(total)
    icon.total = total
  end
  function icon.setIncomingPreview() end
  function icon.setExternalPreview()
    icon.previews = icon.previews + 1
  end
  function icon.setExternalPulse(on)
    icon.pulse = on
  end

  local runtime = {
    store = Store.New({ maxMessagesPerConversation = 10 }),
    panelRegistry = PanelRegistry.New(),
    externalPreview = ExternalPreview.New({
      now = function()
        return 1
      end,
    }),
  }
  local surfaces = {
    getWindow = function()
      return nil
    end,
    isWindowVisible = function()
      return false
    end,
    buildMessagePreview = function()
      return nil
    end,
    getIcon = function()
      return icon
    end,
    getMinimapIcon = function()
      return nil
    end,
    getLdbObject = function()
      return nil
    end,
    getExternalPreview = runtime.externalPreview.get,
    getPanelRegistry = function()
      return runtime.panelRegistry
    end,
  }
  runtime.updateIconSurfaces = function()
    log[#log + 1] = "icons"
    IconSurfaces.Update({}, surfaces)
  end
  runtime.window = {
    registerPanel = function()
      return true
    end,
    refreshPanelBadge = function(key)
      log[#log + 1] = "tab:" .. key
    end,
  }
  runtime.panelRegistry.bind(runtime.window)
  local callbacks = WindowCallbacks.Create({
    runtime = runtime,
    characterState = {},
    refreshWindow = function()
      log[#log + 1] = "window"
    end,
  })
  return callbacks, runtime, icon, log
end

return function()
  -- test_mark_all_read_clears_an_addon_preview_and_its_pulse
  do
    local callbacks, runtime, icon = setup()
    runtime.externalPreview.set("ca", { sender = "CA", text = "lead", pulse = true }, false)
    runtime.updateIconSurfaces()
    assert(icon.previews == 1 and icon.pulse == true, "the addon preview shows and pulses")
    callbacks.onMarkAllRead()
    assert(runtime.externalPreview.get() == nil, "the addon preview is cleared")
    assert(icon.pulse == false, "the pulse stops with the preview")
  end

  -- test_mark_all_read_calls_each_panels_callback
  do
    local callbacks, runtime = setup()
    local calls = 0
    runtime.panelRegistry.register("ca", {
      onMarkAllRead = function()
        calls = calls + 1
      end,
    })
    callbacks.onMarkAllRead()
    assert(calls == 1, "onMarkAllRead ran once, got " .. calls)
  end

  -- test_a_throwing_callback_stops_neither_the_next_panel_nor_wm
  do
    local callbacks, runtime = setup()
    Store.EnsureConversation(runtime.store, "wow::WOW::jaina").unreadCount = 3
    local reached = false
    runtime.panelRegistry.register("bad", {
      onMarkAllRead = function()
        error("addon bug")
      end,
    })
    runtime.panelRegistry.register("good", {
      onMarkAllRead = function()
        reached = true
      end,
    })
    local ok = pcall(callbacks.onMarkAllRead)
    assert(ok, "WM does not raise")
    assert(reached, "the next panel still ran")
    assert(runtime.store.conversations["wow::WOW::jaina"].unreadCount == 0, "WM's own mark-read still happened")
  end

  -- test_icons_read_badge_again_after_the_callbacks
  do
    local callbacks, runtime, icon = setup()
    local waiting = 4
    runtime.panelRegistry.register("ca", {
      badge = function()
        return waiting
      end,
      onMarkAllRead = function()
        waiting = 0
      end,
    })
    runtime.updateIconSurfaces()
    assert(icon.total == 4, "badge counted before, got " .. tostring(icon.total))
    callbacks.onMarkAllRead()
    assert(icon.total == 0, "badge re-read after the callback, got " .. tostring(icon.total))
  end

  -- test_panel_tabs_refresh_then_icons_then_the_window
  do
    local callbacks, runtime, _, log = setup()
    runtime.panelRegistry.register("ca", {})
    callbacks.onMarkAllRead()
    assert(table.concat(log, ",") == "tab:ca,icons,window", "order: " .. table.concat(log, ","))
  end

  -- test_a_panel_without_the_callback_is_fine
  do
    local callbacks, runtime = setup()
    runtime.panelRegistry.register("quiet", { title = "Quiet" })
    assert(pcall(callbacks.onMarkAllRead), "no callback, no error")
  end

  -- test_mark_all_read_works_before_the_runtime_is_bound
  do
    local callbacks, runtime = setup()
    runtime.panelRegistry = nil
    runtime.externalPreview = nil
    runtime.updateIconSurfaces = nil
    runtime.window = nil
    assert(pcall(callbacks.onMarkAllRead), "bare runtime is tolerated")
  end
end
