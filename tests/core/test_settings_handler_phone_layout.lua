local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

return function()
  -- test_changing_the_window_style_saves_and_offers_a_reload
  do
    local shown = 0
    local savedPopup = rawget(_G, "StaticPopup_Show")
    rawset(_G, "StaticPopup_Show", function()
      shown = shown + 1
    end)
    local settings = {}
    local onChange = SettingsHandler.Create({ runtime = { store = { config = {} } }, accountSettings = settings })
    onChange("phoneLayout", false)
    rawset(_G, "StaticPopup_Show", savedPopup)
    assert(settings.phoneLayout == false, "saved")
    assert(shown == 1, "the player is offered a reload")
  end
end
