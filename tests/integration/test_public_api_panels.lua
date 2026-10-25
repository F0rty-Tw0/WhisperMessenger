local PublicApiEnv = require("tests.helpers.public_api_env")

return function()
  -- test_panel_registered_before_the_window_opens_through_the_api
  local runtime, api = PublicApiEnv.Initialize({})
  local ok, err = pcall(function()
    local shows, hides = 0, 0
    local host
    assert(runtime.window == nil, "the window is built on first open")
    assert(api.RegisterPanel("ca", {
      title = "Alerts",
      onShow = function(frame)
        shows = shows + 1
        host = frame
      end,
      onHide = function()
        hides = hides + 1
      end,
    }) == true, "RegisterPanel succeeds before the window exists")
    assert(api.ShowPanel("ca") == true, "ShowPanel opens the window on the panel")
    assert(runtime.isWindowVisible() == true, "window shown")
    assert(shows == 1 and host ~= nil and host:IsShown(), "onShow got the shown host frame")
    assert(api.IsPanelShown("ca") == true, "the API reports it shown")
    assert(not runtime.window.contactsPane:IsShown(), "the panel replaces the contacts list")
    assert(api.TogglePanel("ca") == true, "TogglePanel closes it")
    assert(hides == 1, "onHide once, got " .. hides)
    assert(runtime.isWindowVisible() == false, "the window closes with it")
    assert(api.IsPanelShown("ca") == false)
  end)
  PublicApiEnv.Reset()
  assert(ok, err)

  -- test_a_panel_opening_another_from_its_show_leaves_one_tracked_frame
  do
    local runtime, api = PublicApiEnv.Initialize({})
    local ok, err = pcall(function()
      local frames = {}
      assert(api.RegisterPanel("a", {
        title = "A",
        onShow = function(frame)
          frames.a = frame
          api.ShowPanel("b")
        end,
      }) == true)
      assert(api.RegisterPanel("b", {
        title = "B",
        onShow = function(frame)
          frames.b = frame
        end,
      }) == true)
      assert(api.ShowPanel("a") == true)
      assert(frames.b:IsShown() and not frames.a:IsShown(), "only the panel it moved to shows")
      assert(api.IsPanelShown("b") == true and api.IsPanelShown("a") == false, "and it is the tracked one")
      runtime.window.hidePanel()
      assert(not frames.b:IsShown() and not frames.a:IsShown(), "closing hides every panel frame")
    end)
    PublicApiEnv.Reset()
    assert(ok, err)
  end

  -- test_refresh_panel_badge_updates_icons_without_window
  do
    local runtime, api = PublicApiEnv.Initialize({})
    local ok, err = pcall(function()
      local leads = 0
      assert(api.RegisterPanel("ca", {
        title = "Alerts",
        onShow = function() end,
        badge = function()
          return leads
        end,
      }) == true)
      local label = runtime.icon.badgeLabel
      assert(not runtime.icon.badge:IsShown(), "no leads: no number")
      leads = 2
      assert(api.RefreshPanelBadge("ca") == true)
      assert(runtime.window == nil, "the window is still not built")
      assert(runtime.icon.badge:IsShown() and label:GetText() == "2", "icon shows 2, got " .. tostring(label:GetText()))
    end)
    PublicApiEnv.Reset()
    assert(ok, err)
  end
end
