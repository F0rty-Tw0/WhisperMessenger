-- Composition test: a theme change repaints every built surface once, from
-- both places it can start: the theme setting (the settings handler) and a
-- live preset's source changing before the window exists (LiveThemeSync).

local FakeUI = require("tests.helpers.fake_ui")
local PanelRegistry = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelRegistry")
local WindowRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime")

local LIVE_PRESET = "ellesmere_ui"

local function noop() end

local function counter(repaints, surface)
  return function()
    repaints[surface] = (repaints[surface] or 0) + 1
  end
end

local function fakeCoordinatorModule(trackers)
  return {
    Create = function(coordOptions)
      trackers.coordOptions = coordOptions
      return {
        buildSelectionState = function()
          return {}
        end,
        refreshWindow = noop,
        setWindowVisible = noop,
        isWindowVisible = function()
          return false
        end,
        findLatestUnreadKey = noop,
        scheduleAvailabilityRefresh = noop,
        scheduleIncomingRefresh = noop,
        updateIconSurfaces = noop,
      }
    end,
  }
end

local function fakeToggleIcon(repaints)
  return {
    Create = function()
      return {
        frame = { SetPoint = noop, Show = noop, Hide = noop },
        setUnreadCount = noop,
        setIncomingPreview = noop,
        refreshTheme = counter(repaints, "widget"),
      }
    end,
  }
end

local function fakeMinimapIconRuntime(repaints)
  return {
    Create = function()
      return {
        minimapIcon = { setShown = noop, setUnreadCount = noop, refreshTheme = counter(repaints, "minimap") },
        getLdbObject = noop,
      }
    end,
  }
end

local function fakeTheme(trackers)
  return {
    DEFAULT_PRESET = "wow_default",
    ResolvePreset = function(key)
      return key, true
    end,
    GetPreset = function()
      return LIVE_PRESET
    end,
    IsLivePreset = function(key)
      return key == LIVE_PRESET
    end,
    SetPreset = function(key)
      trackers.livePresetApplied = key
      return true
    end,
  }
end

local function build(settings)
  local runtime = {
    accountState = { settings = settings },
    localProfileId = "me",
    chatApi = {},
    panelRegistry = PanelRegistry.New(),
    store = { conversations = {}, config = {} },
  }
  local trackers = { repaints = {}, themeListeners = {} }
  local factory = FakeUI.NewFactory()
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  uiParent.GetCenter = function()
    return 500, 400
  end
  uiParent.GetTop = function()
    return 800
  end

  local controller = WindowRuntime.Create({
    runtime = runtime,
    accountState = runtime.accountState,
    characterState = { window = {}, icon = {} },
    defaultCharacterState = { window = {}, icon = {} },
    uiFactory = factory,
    uiParent = uiParent,
    bootstrap = {},
    contactsList = {
      BuildItemsForProfile = function()
        return {}
      end,
    },
    messengerWindow = {
      Create = function(_factory, windowOptions)
        trackers.windowOptions = windowOptions
        return { frame = factory.CreateFrame("Frame", nil, nil), refreshTheme = counter(trackers.repaints, "window") }
      end,
    },
    toggleIcon = fakeToggleIcon(trackers.repaints),
    minimapIconRuntime = fakeMinimapIconRuntime(trackers.repaints),
    windowCoordinator = fakeCoordinatorModule(trackers),
    sendHandler = { HandleSend = noop },
    presenceCache = { RefreshPresence = noop },
    fonts = {},
    theme = fakeTheme(trackers),
    ellesmereBridge = {
      OnChange = function(listener)
        trackers.themeListeners[#trackers.themeListeners + 1] = listener
      end,
      Install = function()
        return true
      end,
    },
    markConversationRead = noop,
    requestAvailability = noop,
  })

  local detached = trackers.coordOptions.getDetachedPreview()
  if detached then
    detached.refreshTheme = counter(trackers.repaints, "detached")
  end
  return controller, trackers
end

local function liveThemeChanged(trackers)
  for _, listener in ipairs(trackers.themeListeners) do
    listener()
  end
end

local function assertRepaints(repaints, expected, when)
  for _, surface in ipairs({ "window", "widget", "minimap", "detached" }) do
    local got, want = repaints[surface] or 0, expected[surface] or 0
    assert(got == want, when .. ": " .. surface .. " repaints " .. got .. " time(s), expected " .. want)
  end
end

return function()
  local function test_theme_setting_repaints_every_built_surface_once()
    local controller, trackers = build({ iconMode = "both", widgetPreviewPosition = "detached" })
    controller.ensureWindow()

    trackers.windowOptions.onSettingChanged("themePreset", "elvui_dark")

    assertRepaints(trackers.repaints, { window = 1, widget = 1, minimap = 1, detached = 1 }, "theme setting")
  end

  -- The hidden button must come back in the new theme when its mode returns.
  local function test_theme_setting_repaints_surfaces_the_icon_mode_hides()
    local controller, trackers = build({ iconMode = "both" })
    controller.ensureWindow()
    trackers.windowOptions.onSettingChanged("iconMode", "none")

    trackers.windowOptions.onSettingChanged("themePreset", "elvui_dark")

    assertRepaints(trackers.repaints, { window = 1, widget = 1, minimap = 1 }, "theme setting with icons off")
  end

  local function test_theme_setting_skips_surfaces_never_built()
    local controller, trackers = build({ iconMode = "minimap" })
    controller.ensureWindow()

    trackers.windowOptions.onSettingChanged("themePreset", "elvui_dark")

    assertRepaints(trackers.repaints, { window = 1, minimap = 1 }, "theme setting in minimap mode")
  end

  local function test_live_theme_change_before_the_window_repaints_every_built_surface()
    local _, trackers = build({ iconMode = "both", widgetPreviewPosition = "detached" })
    assert(trackers.windowOptions == nil, "the window is not created yet")

    liveThemeChanged(trackers)

    assert(trackers.livePresetApplied == LIVE_PRESET, "the live preset is applied again")
    assertRepaints(trackers.repaints, { widget = 1, minimap = 1, detached = 1 }, "live theme, no window")
  end

  local function test_live_theme_change_with_the_window_repaints_through_the_setting()
    local controller, trackers = build({ iconMode = "both", widgetPreviewPosition = "detached" })
    controller.ensureWindow()

    liveThemeChanged(trackers)

    assertRepaints(trackers.repaints, { window = 1, widget = 1, minimap = 1, detached = 1 }, "live theme with the window")
  end

  test_theme_setting_repaints_every_built_surface_once()
  test_theme_setting_repaints_surfaces_the_icon_mode_hides()
  test_theme_setting_skips_surfaces_never_built()
  test_live_theme_change_before_the_window_repaints_every_built_surface()
  test_live_theme_change_with_the_window_repaints_through_the_setting()
end
