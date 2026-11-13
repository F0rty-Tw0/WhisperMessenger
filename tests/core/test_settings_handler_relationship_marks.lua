local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local Relationship = require("WhisperMessenger.Model.Relationship")

-- accountSettings is the table the runtime reads IsEnabled from, as in production.
local function build(withRefresh)
  local accountSettings = {}
  local counter = { refreshes = 0 }
  local runtime = { store = { config = {} }, accountState = { settings = accountSettings }, relationshipCache = {} }
  if withRefresh then
    runtime.refreshWindow = function()
      counter.refreshes = counter.refreshes + 1
    end
  end
  return SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings }), runtime, accountSettings, counter
end

return function()
  -- test_turning_marks_off_clears_the_cache_and_repaints
  do
    local onChange, runtime, settings, counter = build(true)
    local stale = { ["wow::a"] = { value = false, at = 1 } }
    runtime.relationshipCache = stale
    onChange("showRelationshipMarks", false)
    assert(settings.showRelationshipMarks == false, "the choice persists")
    assert(runtime.relationshipCache ~= stale and next(runtime.relationshipCache) == nil, "the cache is dropped")
    assert(Relationship.IsEnabled(runtime) == false, "marks are off")
    assert(counter.refreshes == 1, "the window repaints once, got " .. counter.refreshes)
  end

  -- test_turning_marks_on_clears_the_cache_and_repaints
  do
    local onChange, runtime, _, counter = build(true)
    onChange("showRelationshipMarks", false)
    local stale = { ["wow::a"] = { value = false, at = 1 } }
    runtime.relationshipCache = stale
    onChange("showRelationshipMarks", true)
    assert(runtime.relationshipCache ~= stale and next(runtime.relationshipCache) == nil, "the cache is dropped again")
    assert(Relationship.IsEnabled(runtime) == true, "marks are on")
    assert(counter.refreshes == 2, "the window repaints again, got " .. counter.refreshes)
  end

  -- test_other_settings_leave_the_cache_alone
  do
    local onChange, runtime = build(true)
    local warm = { ["wow::a"] = { value = false, at = 1 } }
    runtime.relationshipCache = warm
    onChange("hideMessagePreview", true)
    assert(runtime.relationshipCache == warm, "only the marks setting drops the cache")
  end

  -- test_toggle_with_no_window_yet_is_harmless
  do
    local onChange, runtime = build(false)
    local ok, err = pcall(onChange, "showRelationshipMarks", false)
    assert(ok, "toggling with no window or refresh hook must not error: " .. tostring(err))
    assert(Relationship.IsEnabled(runtime) == false, "off is remembered for the next open")
    ok, err = pcall(onChange, "showRelationshipMarks", true)
    assert(ok, tostring(err))
    assert(Relationship.IsEnabled(runtime) == true and next(runtime.relationshipCache) == nil, "next open resolves fresh with marks on")
  end
end
