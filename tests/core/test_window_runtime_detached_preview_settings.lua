local DetachedPreviewRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.DetachedPreviewRuntime")

local function build(settings, characterState, shared)
  local env = {
    log = {},
    accountState = { settings = settings or {}, sharedDetachedPreview = shared },
    characterState = characterState or {},
    surface = nil,
  }
  local function applySavedSpot()
    env.log[#env.log + 1] = "apply"
  end
  env.ctx = {
    accountState = env.accountState,
    characterState = env.characterState,
    getSurface = function()
      return env.surface
    end,
    ensureSurface = function()
      env.log[#env.log + 1] = "ensure"
      env.surface = { applySavedSpot = applySavedSpot }
    end,
    updateIconSurfaces = function()
      env.log[#env.log + 1] = "update"
    end,
  }
  env.surfaceApply = applySavedSpot
  return env
end

local function logOf(env)
  return table.concat(env.log, ",")
end

return function()
  -- test_position_change_to_detached_creates_and_refreshes
  do
    local env = build()
    DetachedPreviewRuntime.OnSettingChanged(env.ctx, "widgetPreviewPosition", "detached")
    assert(logOf(env) == "ensure,update", "ensure once, then update; got " .. logOf(env))
  end

  -- test_position_change_away_refreshes_without_creating
  do
    local env = build()
    DetachedPreviewRuntime.OnSettingChanged(env.ctx, "widgetPreviewPosition", "right")
    assert(logOf(env) == "update", "update only; got " .. logOf(env))
  end

  -- test_share_on_overwrites_shared_spot
  do
    local env = build({}, { detachedPreview = { x = 1, y = -1 } }, { x = 9, y = -9 })
    env.surface = { applySavedSpot = env.surfaceApply }
    DetachedPreviewRuntime.OnSettingChanged(env.ctx, "shareWidgetPosition", true)
    local shared = env.accountState.sharedDetachedPreview
    assert(shared.x == 1 and shared.y == -1, "shared spot takes the character spot")
    assert(shared ~= env.characterState.detachedPreview, "shared spot is a copy")
    assert(logOf(env) == "apply", "spot re-applied; got " .. logOf(env))
  end

  -- test_share_on_without_character_spot_clears_shared_spot
  do
    local env = build({}, {}, { x = 9, y = -9 })
    DetachedPreviewRuntime.OnSettingChanged(env.ctx, "shareWidgetPosition", true)
    assert(env.accountState.sharedDetachedPreview == nil, "no character spot leaves no shared spot")
  end

  -- test_share_on_without_surface_only_copies
  do
    local env = build({}, { detachedPreview = { x = 2, y = -2 } })
    DetachedPreviewRuntime.OnSettingChanged(env.ctx, "shareWidgetPosition", true)
    assert(env.accountState.sharedDetachedPreview.x == 2, "spot copied")
    assert(logOf(env) == "", "nothing created or applied; got " .. logOf(env))
  end

  -- test_share_off_reapplies_spot
  do
    local env = build({}, { detachedPreview = { x = 1, y = -1 } }, { x = 9, y = -9 })
    env.surface = { applySavedSpot = env.surfaceApply }
    DetachedPreviewRuntime.OnSettingChanged(env.ctx, "shareWidgetPosition", false)
    assert(logOf(env) == "apply", "spot re-applied; got " .. logOf(env))
    assert(env.accountState.sharedDetachedPreview.x == 9, "shared spot kept")
  end

  -- test_icon_mode_refreshes_only_when_detached
  do
    local env = build({ widgetPreviewPosition = "right" })
    DetachedPreviewRuntime.OnSettingChanged(env.ctx, "iconMode", "widget")
    assert(logOf(env) == "", "no refresh when not detached; got " .. logOf(env))
    env.accountState.settings.widgetPreviewPosition = "detached"
    DetachedPreviewRuntime.OnSettingChanged(env.ctx, "iconMode", "widget")
    assert(logOf(env) == "update", "refresh when detached; got " .. logOf(env))
  end

  -- test_other_keys_do_nothing
  do
    local env = build({ widgetPreviewPosition = "detached" })
    DetachedPreviewRuntime.OnSettingChanged(env.ctx, "lockToggleIcon", true)
    assert(logOf(env) == "", "unrelated key ignored; got " .. logOf(env))
  end
end
