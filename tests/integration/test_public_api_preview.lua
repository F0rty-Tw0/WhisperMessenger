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

  local function test_turning_previews_off_drops_the_external_preview()
    local runtime, api = PublicApiEnv.Initialize({})
    local ok, err = pcall(function()
      assert(api.ShowPreview("ca", { sender = "Crafter", text = "Needs Belt" }) == true)
      assert(api.IsPreviewShown("ca") == true, "shown while previews are on")
      runtime.accountState.settings.showWidgetMessagePreview = false
      runtime.refreshWindow()
      assert(runtime.icon.isExternalPreviewShown() == false, "the widget hides it once previews are off")
      assert(api.IsPreviewShown("ca") == false, "the API reports it hidden")
      assert(runtime.externalPreview.keyOf() == nil, "the slot is dropped")
    end)
    PublicApiEnv.Reset()
    assert(ok, err)
  end

  local function test_detail_reaches_the_widget_third_row()
    local runtime, api = PublicApiEnv.Initialize({})
    local ok, err = pcall(function()
      local detail = "Your alt Artio can craft it"
      assert(api.ShowPreview("ca", { sender = "Crafter", text = "Needs Belt", detail = detail }) == true)
      local label = runtime.icon.previewDetailLabel
      assert(label ~= nil and label:IsShown() == true and label:GetText() == detail, "the widget shows the detail row")
    end)
    PublicApiEnv.Reset()
    assert(ok, err)
  end

  test_right_click_dismisses_external_without_acknowledging()
  test_detail_reaches_the_widget_third_row()
  test_previews_turned_off_refuse_show()
  test_turning_previews_off_drops_the_external_preview()
end
