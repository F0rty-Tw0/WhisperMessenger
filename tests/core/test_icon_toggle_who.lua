local PanelRegistry = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelRegistry")
local ExternalPreview = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ExternalPreview")
local IconToggle = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconToggle")
local ToggleFlow = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ToggleFlow")
local WhoTriggers = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WhoTriggers")

local function noop() end

-- opts: visible, whisperUnread, toggleKey (the chat the toggle stub opens onto
-- and the open-target stub reports), realFlow (use ToggleFlow.Create for the
-- toggle and its open target), order (a list the toggle stub appends "toggle"
-- to). Returns the wrapped click, the list of AskFor calls and the runtime.
local function setup(opts)
  opts = opts or {}
  local asks = {}
  local visible = opts.visible == true
  local runtime = {
    panelRegistry = PanelRegistry.New(),
    externalPreview = ExternalPreview.New({
      now = function()
        return 1
      end,
    }),
    activeConversationKey = opts.activeKey,
    store = { conversations = { ["party::me"] = { channel = "PARTY" } } },
  }
  local window = {
    registerPanel = function()
      return true
    end,
    showPanel = function()
      return true
    end,
    getTabMode = function()
      return "whispers"
    end,
  }
  runtime.window = window
  runtime.ensureWindow = noop
  runtime.setWindowVisible = function(nextVisible)
    visible = nextVisible
  end
  runtime.isWindowVisible = function()
    return visible
  end
  runtime.isCompetitiveContent = function()
    return false
  end
  runtime.isMythicLockdown = function()
    return false
  end
  runtime.panelRegistry.bind(window)
  runtime.getWidgetIcon = function()
    return {
      isExternalPreviewShown = function()
        return false
      end,
      isRiding = function()
        return false
      end,
    }
  end

  local toggle = function()
    if opts.order then
      opts.order[#opts.order + 1] = "toggle"
    end

    return opts.toggleKey
  end
  local openTargetKey = function()
    return opts.toggleKey
  end
  if opts.realFlow then
    local flow = ToggleFlow.Create({
      runtime = runtime,
      ensureWindow = runtime.ensureWindow,
      isWindowVisible = runtime.isWindowVisible,
      setWindowVisible = runtime.setWindowVisible,
      getWindow = function()
        return window
      end,
    })
    toggle = flow.toggle
    openTargetKey = flow.openTargetKey
  end
  local function buildContacts()
    return { { channel = "WOW", unreadCount = opts.whisperUnread or 0 } }
  end
  return IconToggle.Wrap(runtime, toggle, buildContacts, openTargetKey), asks, runtime
end

-- Runs the click with WhoTriggers.AskFor stubbed on the module table. A given
-- order list gets "ask" appended per call.
local function click(onToggle, asks, order)
  local original = WhoTriggers.AskFor
  WhoTriggers.AskFor = function(runtime, key)
    asks[#asks + 1] = { runtime = runtime, key = key }
    if order then
      order[#order + 1] = "ask"
    end
  end
  local ok, err = pcall(onToggle)
  WhoTriggers.AskFor = original
  assert(ok, err)
end

local function test_widget_click_opening_chat_asks_who()
  local onToggle, asks, runtime = setup({ whisperUnread = 1, toggleKey = "wow::jaina" })
  click(onToggle, asks)
  assert(#asks == 1, "expected one ask, got " .. #asks)
  assert(asks[1].runtime == runtime and asks[1].key == "wow::jaina")
end

local function test_widget_click_asks_before_toggle()
  local order = {}
  local onToggle, asks = setup({ whisperUnread = 1, toggleKey = "wow::jaina", order = order })
  click(onToggle, asks, order)
  assert(order[1] == "ask" and order[2] == "toggle", "ask must run before the window opens, got " .. table.concat(order, ","))
end

local function test_widget_fallback_open_asks_who()
  local onToggle, asks, runtime = setup({ toggleKey = "wow::jaina" })
  click(onToggle, asks)
  assert(#asks == 1, "expected one ask, got " .. #asks)
  assert(asks[1].runtime == runtime and asks[1].key == "wow::jaina")
end

local function test_widget_click_closing_window_asks_nothing()
  local onToggle, asks = setup({ visible = true, toggleKey = "wow::jaina" })
  click(onToggle, asks)
  assert(#asks == 0, "closing asks nothing, got " .. #asks)
end

local function test_compact_list_open_asks_nothing()
  local onToggle, asks = setup({ whisperUnread = 1, toggleKey = nil })
  click(onToggle, asks)
  assert(#asks == 0, "a toggle that selects no chat asks nothing, got " .. #asks)
end

local function test_addon_panel_open_asks_nothing()
  local onToggle, asks, runtime = setup({ toggleKey = "wow::jaina" })
  runtime.panelRegistry.register("ca", {
    title = "Alerts",
    onShow = noop,
    badge = function()
      return 2
    end,
  })
  click(onToggle, asks)
  assert(#asks == 0, "a panel open asks nothing, got " .. #asks)
end

-- The old active chat sits on another tab: opening shows nothing selected, so
-- the click must not ask about it.
local function test_open_without_tab_match_asks_nothing()
  local onToggle, asks, runtime = setup({ realFlow = true, activeKey = "party::me" })
  click(onToggle, asks)
  assert(runtime.isWindowVisible() == true, "the window opened")
  assert(#asks == 0, "nothing was selected, got " .. #asks)
end

return function()
  test_widget_click_opening_chat_asks_who()
  test_widget_click_asks_before_toggle()
  test_widget_fallback_open_asks_who()
  test_widget_click_closing_window_asks_nothing()
  test_compact_list_open_asks_nothing()
  test_addon_panel_open_asks_nothing()
  test_open_without_tab_match_asks_nothing()
end
