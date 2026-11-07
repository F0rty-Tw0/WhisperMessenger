local PublicApi = require("WhisperMessenger.Core.PublicApi")

local function build(runtime)
  return PublicApi.Build(runtime)
end

local function withSettings(settings, active)
  return { accountState = { settings = settings }, compactLayoutActive = active }
end

return function()
  -- test_true_when_the_built_window_is_compact
  do
    assert(build(withSettings({}, true)).IsCompactWindow() == true)
  end

  -- test_false_when_the_built_window_is_not_compact
  do
    assert(build(withSettings({}, false)).IsCompactWindow() == false)
  end

  -- test_runtime_wins_over_the_setting
  do
    local api = build(withSettings({ compactLayout = true }, false))
    assert(api.IsCompactWindow() == false, "window built full-size stays false until reload")
  end

  -- test_setting_off_is_false_before_the_window_is_built
  do
    assert(build(withSettings({ compactLayout = false })).IsCompactWindow() == false)
  end

  -- test_setting_on_is_true_before_the_window_is_built
  do
    assert(build(withSettings({ compactLayout = true })).IsCompactWindow() == true)
  end

  -- test_unset_setting_counts_as_compact
  do
    assert(build(withSettings({})).IsCompactWindow() == true)
  end

  -- test_false_without_settings
  do
    assert(build({}).IsCompactWindow() == false)
  end

  -- test_refused_when_addon_integration_is_off
  do
    local api = build(withSettings({ allowAddonIntegration = false, compactLayout = true }, true))
    assert(api.IsCompactWindow() == false, "refused calls return false")
  end
end
