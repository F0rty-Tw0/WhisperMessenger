local PanelRegistry = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelRegistry")
local PublicApi = require("WhisperMessenger.Core.PublicApi")

local function noop() end

local function build()
  local runtime = { panelRegistry = PanelRegistry.New() }
  return PublicApi.Build(runtime), runtime
end

return function()
  -- test_on_unread_changed_function_is_accepted_and_copied
  do
    local api, runtime = build()
    local function onUnreadChanged() end
    assert(api.RegisterPanel("k", { title = "T", onShow = noop, onUnreadChanged = onUnreadChanged }) == true)
    assert(runtime.panelRegistry.get("k").onUnreadChanged == onUnreadChanged, "the stored copy keeps the callback")
  end

  -- test_on_unread_changed_non_function_is_refused
  do
    local api, runtime = build()
    assert(api.RegisterPanel("k", { title = "T", onShow = noop, onUnreadChanged = "x" }) == false)
    assert(runtime.panelRegistry.get("k") == nil, "nothing stored")
  end
end
