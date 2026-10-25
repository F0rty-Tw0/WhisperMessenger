local PanelRegistry = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelRegistry")
local PublicApi = require("WhisperMessenger.Core.PublicApi")

local function noop() end

local function validPanel()
  return { title = "Alerts", icon = "Interface\\Icons\\INV_Misc_Bell_01", onShow = noop }
end

-- opts: visible, competitive, mythic, showResult, windowPanel (what
-- getVisiblePanel reports), withWindow (window built up front).
local function makeRuntime(opts)
  opts = opts or {}
  local calls = {}
  local visible = opts.visible == true
  local function log(entry)
    calls[#calls + 1] = entry
  end
  local runtime = { panelRegistry = PanelRegistry.New() }
  local function buildWindow()
    return {
      registerPanel = function()
        return true
      end,
      showPanel = function(key)
        log("showPanel:" .. key)
        return opts.showResult ~= false
      end,
      hidePanel = function()
        log("hidePanel")
      end,
      getVisiblePanel = function()
        return opts.windowPanel
      end,
      refreshPanelBadge = function(key)
        log("badge:" .. key)
      end,
    }
  end
  runtime.ensureWindow = function()
    log("ensure")
    if runtime.window == nil then
      runtime.window = buildWindow()
      runtime.panelRegistry.bind(runtime.window)
    end
  end
  runtime.setWindowVisible = function(v)
    visible = v
    log("visible:" .. tostring(v))
  end
  runtime.isWindowVisible = function()
    return visible
  end
  runtime.startConversation = function(name)
    log("start:" .. name)
    return true
  end
  runtime.setComposerText = function(text)
    log("draft:" .. text)
  end
  runtime.isCompetitiveContent = function()
    return opts.competitive == true
  end
  runtime.isMythicLockdown = function()
    return opts.mythic == true
  end
  if opts.withWindow then
    runtime.window = buildWindow()
    runtime.panelRegistry.bind(runtime.window)
  end
  return runtime, calls
end

local function joined(calls)
  return table.concat(calls, ",")
end

local function withCombat(inCombat, fn)
  local saved = _G.InCombatLockdown
  rawset(_G, "InCombatLockdown", function()
    return inCombat
  end)
  local ok, err = pcall(fn)
  rawset(_G, "InCombatLockdown", saved)
  assert(ok, err)
end

local function registered(opts)
  local r, calls = makeRuntime(opts)
  local api = PublicApi.Build(r)
  assert(api.RegisterPanel("ca", validPanel()) == true)
  return api, r, calls
end

local function with(overrides)
  local p = validPanel()
  for k, v in pairs(overrides) do
    p[k] = v
  end
  return p
end

return function()
  -- test_register_validates
  do
    local api = PublicApi.Build((makeRuntime()))
    assert(api.RegisterPanel(nil, validPanel()) == false, "nil key")
    assert(api.RegisterPanel("", validPanel()) == false, "empty key")
    assert(api.RegisterPanel(5, validPanel()) == false, "number key")
    assert(api.RegisterPanel("a", "panel") == false, "panel not a table")
    assert(api.RegisterPanel("a", with({ title = "" })) == false, "empty title")
    assert(api.RegisterPanel("a", with({ icon = {} })) == false, "table icon")
    assert(api.RegisterPanel("a", with({ onShow = false })) == false, "onShow missing")
    assert(api.RegisterPanel("a", with({ onHide = "x" })) == false, "onHide not a function")
    assert(api.RegisterPanel("a", with({ badge = 5 })) == false, "badge not a function")
    assert(api.RegisterPanel("a", with({ icon = 134400 })) == true, "file id icon, minimal panel")
    assert(api.RegisterPanel("a", validPanel()) == false, "duplicate key")
  end

  -- test_show_unknown_key_is_false_and_opens_nothing
  do
    local r, calls = makeRuntime()
    assert(PublicApi.Build(r).ShowPanel("nope") == false)
    assert(#calls == 0, "calls: " .. joined(calls))
  end

  -- test_show_refused_cases_open_nothing
  do
    local api, _, calls = registered({ competitive = true })
    assert(api.ShowPanel("ca") == false and #calls == 0, "competitive: " .. joined(calls))
    api, _, calls = registered({ mythic = true })
    assert(api.ShowPanel("ca") == false and #calls == 0, "mythic: " .. joined(calls))
    withCombat(true, function()
      local combatApi, _, combatCalls = registered()
      assert(combatApi.ShowPanel("ca") == false and #combatCalls == 0, "combat, closed: " .. joined(combatCalls))
    end)
  end

  -- test_show_sequence
  do
    local api, _, calls = registered()
    assert(api.ShowPanel("ca") == true)
    assert(joined(calls) == "ensure,visible:true,showPanel:ca", "calls: " .. joined(calls))
    local refusing = registered({ showResult = false })
    assert(refusing.ShowPanel("ca") == false, "returns window.showPanel's result")
  end

  -- test_toggle_closes_panel_and_window
  do
    local api, _, calls = registered({ withWindow = true, visible = true, windowPanel = "ca" })
    assert(api.TogglePanel("ca") == true)
    assert(joined(calls) == "hidePanel,visible:false", "calls: " .. joined(calls))
  end

  -- test_toggle_opens_when_not_shown
  do
    local api, _, calls = registered({ withWindow = true, visible = true, windowPanel = "other" })
    assert(api.TogglePanel("ca") == true)
    assert(joined(calls) == "ensure,visible:true,showPanel:ca", "calls: " .. joined(calls))
  end

  -- test_is_panel_shown_needs_a_visible_window
  do
    local api = registered({ withWindow = true, visible = true, windowPanel = "ca" })
    assert(api.IsPanelShown("ca") == true)
    assert(api.IsPanelShown("other") == false)
    assert(registered({ withWindow = true, visible = false, windowPanel = "ca" }).IsPanelShown("ca") == false, "hidden window")
    assert(registered({ visible = true }).IsPanelShown("ca") == false, "no window yet")
    assert(api.IsPanelShown(7) == false, "bad key")
  end

  -- test_refresh_badge
  do
    local api, _, calls = registered({ withWindow = true })
    assert(api.RefreshPanelBadge("ca") == true)
    assert(joined(calls) == "badge:ca", "calls: " .. joined(calls))
    assert(api.RefreshPanelBadge("unknown") == false)
    assert(registered().RefreshPanelBadge("ca") == true, "no window yet: true, no error")
  end

  -- test_open_conversation_closes_an_open_panel
  do
    local api, _, calls = registered({ withWindow = true, visible = true, windowPanel = "ca" })
    assert(api.OpenConversation("Jaina") == true)
    local hide, start
    for i, c in ipairs(calls) do
      if c == "hidePanel" then
        hide = i
      elseif c == "start:Jaina" then
        start = i
      end
    end
    assert(hide ~= nil and start ~= nil and hide < start, "panel closes before the conversation starts: " .. joined(calls))
  end
end
