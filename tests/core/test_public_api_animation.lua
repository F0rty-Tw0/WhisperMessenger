local PublicApi = require("WhisperMessenger.Core.PublicApi")

local function build(settings)
  return PublicApi.Build({ accountState = { settings = settings } }), settings
end

return function()
  -- test_enabled_when_the_setting_is_unset
  do
    assert(build({}).IsAnimationEnabled() == true, "unset counts as on")
  end

  -- test_enabled_when_the_setting_is_on
  do
    assert(build({ windowAnimation = true }).IsAnimationEnabled() == true)
  end

  -- test_disabled_when_the_setting_is_off
  do
    assert(build({ windowAnimation = false }).IsAnimationEnabled() == false)
  end

  -- test_follows_the_setting_live
  do
    local api, settings = build({ windowAnimation = true })
    settings.windowAnimation = false
    assert(api.IsAnimationEnabled() == false, "off after the API was built")
    settings.windowAnimation = true
    assert(api.IsAnimationEnabled() == true, "on again")
  end

  -- test_enabled_when_the_runtime_has_no_settings_yet
  do
    local api = PublicApi.Build({})
    assert(api.IsAnimationEnabled() == true, "no settings table counts as on")
  end

  -- test_refused_when_addon_integration_is_off
  do
    local api = build({ allowAddonIntegration = false, windowAnimation = true })
    assert(api.IsAnimationEnabled() == false, "refused calls return false")
  end
end
