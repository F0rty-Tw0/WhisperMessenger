local PublicApiEnv = require("tests.helpers.public_api_env")

return function()
  local function test_right_click_dismisses_external_without_acknowledging()
    local runtime, api = PublicApiEnv.Initialize({})
    local ok, err = pcall(function()
      assert(runtime.getWidgetIcon() ~= nil, "the widget icon is in use by default")
      local dismissed = 0
      local shown = api.ShowPreview("ca", {
        sender = "Crafter",
        text = "Needs Belt",
        onDismiss = function()
          dismissed = dismissed + 1
        end,
      })
      assert(shown == true, "ShowPreview succeeds on a live runtime")
      assert(runtime.icon.isExternalPreviewShown() == true, "the widget shows the external preview")
      assert(api.IsPreviewShown("ca") == true, "the API reports it shown")

      local frame = runtime.icon.previewFrame
      frame:GetScript("OnMouseUp")(frame, "RightButton")
      assert(api.IsPreviewShown("ca") == false, "right click hides it")
      assert(dismissed == 1, "the caller's onDismiss runs once, got " .. dismissed)
      assert(runtime.accountState.widgetPreviewAcknowledgedAt == nil, "own whispers stay unacknowledged")
    end)
    PublicApiEnv.Reset()
    assert(ok, err)
  end

  local function test_previews_turned_off_refuse_show()
    local _runtime, api = PublicApiEnv.Initialize({ showWidgetMessagePreview = false })
    local ok, result = pcall(api.ShowPreview, "ca", { sender = "Crafter", text = "Needs Belt" })
    PublicApiEnv.Reset()
    assert(ok and result == false, "ShowPreview is refused while previews are off")
  end

  test_right_click_dismisses_external_without_acknowledging()
  test_previews_turned_off_refuse_show()
end
