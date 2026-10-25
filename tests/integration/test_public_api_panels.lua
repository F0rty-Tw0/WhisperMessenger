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
      icon = "x",
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
end
