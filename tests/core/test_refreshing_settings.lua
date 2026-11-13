local RefreshingSettings = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.RefreshingSettings")

local REFRESHING_KEYS = {
  "hideMessagePreview",
  "hideBattleTagNumbers",
  "showPlayerLevels",
  "whoLookups",
  "showRelationshipMarks",
  "showWidgetMessagePreview",
  "widgetPreviewReply",
  "fontFamily",
  "fontSize",
  "fontOutline",
  "fontColor",
  "bubbleColorPreset",
  "timeFormat",
  "timeSource",
  "interfaceLanguage",
  "enabledChannels",
  "showInviteLink",
  "showChannelContext",
}

return function()
  -- test_has_every_refreshing_key
  do
    for _, key in ipairs(REFRESHING_KEYS) do
      assert(RefreshingSettings.Has(key) == true, "expected " .. key .. " to refresh the window")
    end
  end

  -- test_has_rejects_other_keys
  do
    assert(RefreshingSettings.Has("themePreset") == false, "themePreset refreshes on its own path")
    assert(RefreshingSettings.Has("escapeClosesWindow") == false, "escapeClosesWindow needs no window refresh")
    assert(RefreshingSettings.Has(nil) == false, "a nil key is not a refreshing setting")
  end
end
