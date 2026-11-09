-- Composition test: WindowRuntime builds the detached preview surface and
-- wires it into the coordinator, the widget icon and the settings handler.

local FakeUI = require("tests.helpers.fake_ui")
local IconSurfaces = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.IconSurfaces")
local WindowRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime")

local CONVERSATION_KEY = "wow::WOW::arthas-area52"

local function fakeCoordinatorModule(trackers)
  return {
    Create = function(coordOptions)
      trackers.coordOptions = coordOptions
      local visible = false
      local coord = {}
      function coord.buildSelectionState(contacts)
        return { selectedContact = contacts[1], conversation = nil, status = nil }
      end
      function coord.refreshWindow()
        return nil
      end
      function coord.setWindowVisible(nextVisible)
        visible = nextVisible
      end
      function coord.isWindowVisible()
        return visible
      end
      function coord.findLatestUnreadKey()
        return nil
      end
      function coord.scheduleAvailabilityRefresh() end
      function coord.scheduleIncomingRefresh() end
      function coord.updateIconSurfaces()
        if trackers.onUpdate then
          trackers.onUpdate()
        end
      end
      return coord
    end,
  }
end

local function fakeToggleIcon(trackers)
  local noop = function() end
  return {
    Create = function(_uiFactory, options)
      trackers.capturedIconOptions = options
      return {
        frame = { SetPoint = noop, Show = noop, Hide = noop },
        setUnreadCount = noop,
        setIncomingPreview = function(sender)
          trackers.iconSender = sender
        end,
        refreshTheme = noop,
      }
    end,
  }
end

local function fakeMinimapIconRuntime(trackers, factory)
  local noop = function() end
  return {
    Create = function()
      return {
        minimapIcon = {
          frame = factory.CreateFrame("Button", nil, nil),
          setShown = noop,
          setIncomingPreview = function(sender)
            trackers.minimapSender = sender
          end,
          setUnreadCount = noop,
          refreshTheme = noop,
        },
        getLdbObject = function()
          return {}
        end,
      }
    end,
  }
end

local function build(settings)
  local runtime = {
    accountState = { settings = settings },
    localProfileId = "me",
    chatApi = {},
    store = {
      conversations = {
        [CONVERSATION_KEY] = {
          conversationKey = CONVERSATION_KEY,
          displayName = "Arthas-Area52",
          channel = "WOW",
          guid = "Player-1-00000001",
          unreadCount = 1,
          lastIncomingAt = 5,
          lastIncomingPreview = "hi",
          messages = {},
        },
      },
      config = {},
    },
  }
  local trackers = { iconSender = "untouched", minimapSender = "untouched" }
  local factory = FakeUI.NewFactory()
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  uiParent:Show()
  uiParent.GetCenter = function()
    return 500, 400
  end
  uiParent.GetTop = function()
    return 800
  end

  local options = {
    runtime = runtime,
    accountState = runtime.accountState,
    characterState = { window = {}, icon = {} },
    defaultCharacterState = { window = {}, icon = {} },
    uiFactory = factory,
    uiParent = uiParent,
    bootstrap = { _inMythicContent = false },
    contactsList = {
      BuildItemsForProfile = function()
        local convo = runtime.store.conversations[CONVERSATION_KEY]
        return {
          { conversationKey = CONVERSATION_KEY, displayName = convo.displayName, channel = convo.channel, guid = convo.guid },
        }
      end,
    },
    messengerWindow = {
      Create = function(_factory, windowOptions)
        trackers.windowOptions = windowOptions
        return { frame = factory.CreateFrame("Frame", nil, nil) }
      end,
    },
    toggleIcon = fakeToggleIcon(trackers),
    minimapIconRuntime = fakeMinimapIconRuntime(trackers, factory),
    windowCoordinator = fakeCoordinatorModule(trackers),
    sendHandler = { HandleSend = function() end },
    tableUtils = {
      copyState = function(value)
        local copy = {}
        for key, nextValue in pairs(value or {}) do
          copy[key] = nextValue
        end
        return copy
      end,
    },
    presenceCache = { RefreshPresence = function() end },
    fonts = {},
    theme = {
      DEFAULT_PRESET = "wow_default",
      ResolvePreset = function(key)
        return key, true
      end,
    },
    markConversationRead = function() end,
    requestAvailability = function() end,
  }
  return options, runtime, trackers
end

local function updateSurfaces(coordOptions)
  IconSurfaces.Update(coordOptions.buildContacts(), {
    getWindow = coordOptions.getWindow,
    isWindowVisible = function()
      return false
    end,
    buildMessagePreview = coordOptions.buildMessagePreview,
    getIcon = coordOptions.getIcon,
    getMinimapIcon = coordOptions.getMinimapIcon,
    getLdbObject = coordOptions.getLdbObject,
    getDetachedPreview = coordOptions.getDetachedPreview,
    previewDetached = coordOptions.previewDetached,
  })
end

return function()
  local function test_startup_in_mode_none_creates_the_detached_surface()
    local options, _, trackers = build({ iconMode = "none", widgetPreviewPosition = "detached" })
    WindowRuntime.Create(options)
    local o = trackers.coordOptions
    assert(o.getDetachedPreview() ~= nil, "the detached surface exists at startup")
    assert(o.previewDetached() == true, "the coordinator is told the preview is detached")
  end

  local function test_startup_pinned_creates_no_surface()
    local options, _, trackers = build({ iconMode = "both" })
    WindowRuntime.Create(options)
    local o = trackers.coordOptions
    assert(o.getDetachedPreview() == nil, "no detached surface while the preview is pinned")
    assert(o.previewDetached() == false, "the preview is not detached")
  end

  local function test_active_surface_is_detached_in_both_mode()
    local options, runtime, trackers = build({ iconMode = "both", widgetPreviewPosition = "detached" })
    WindowRuntime.Create(options)
    local surface = trackers.coordOptions.getDetachedPreview()
    assert(surface ~= nil, "the detached surface exists")
    assert(runtime.getActivePreviewSurface() == surface, "the active preview surface is the detached card")
  end

  local function test_active_surface_is_the_widget_when_pinned()
    local options, runtime = build({ iconMode = "widget" })
    WindowRuntime.Create(options)
    assert(runtime.getActivePreviewSurface() == runtime.getWidgetIcon(), "the active preview surface is the widget")
  end

  local function test_widget_pulse_sees_the_detached_external()
    local options, _, trackers = build({ iconMode = "both", widgetPreviewPosition = "detached" })
    WindowRuntime.Create(options)
    local shownElsewhere = trackers.capturedIconOptions.isExternalShownElsewhere
    assert(type(shownElsewhere) == "function", "the widget gets an isExternalShownElsewhere check")
    assert(shownElsewhere() == false, "no external preview on the detached card yet")
  end

  local function test_widget_pulse_follows_a_shown_detached_external()
    local options, _, trackers = build({ iconMode = "both", widgetPreviewPosition = "detached" })
    WindowRuntime.Create(options)
    trackers.coordOptions.getDetachedPreview().setExternalPreview({
      sender = "Crafter",
      text = "hello",
      onClick = function() end,
      onDismiss = function() end,
      onShown = function() end,
    })
    assert(trackers.capturedIconOptions.isExternalShownElsewhere() == true, "the external preview shows on the detached card")
  end

  local function test_one_card_in_both_mode()
    local options, _, trackers = build({ iconMode = "both", widgetPreviewPosition = "detached" })
    WindowRuntime.Create(options)
    local o = trackers.coordOptions
    updateSurfaces(o)
    assert(o.getDetachedPreview().previewFrame:IsShown() == true, "the detached card shows the preview")
    assert(trackers.iconSender == nil, "the widget shows no preview, got " .. tostring(trackers.iconSender))
    assert(trackers.minimapSender == nil, "the minimap shows no preview, got " .. tostring(trackers.minimapSender))
  end

  local function test_startup_shows_a_pending_whisper_on_the_detached_card()
    local options, _, trackers = build({ iconMode = "both", widgetPreviewPosition = "detached" })
    trackers.onUpdate = function()
      updateSurfaces(trackers.coordOptions)
    end
    WindowRuntime.Create(options)
    local o = trackers.coordOptions
    assert(o.getDetachedPreview().previewFrame:IsShown() == true, "the detached card shows the pending whisper at startup")
    assert(trackers.iconSender == nil, "the widget shows no preview at startup, got " .. tostring(trackers.iconSender))
    assert(trackers.minimapSender == nil, "the minimap shows no preview at startup, got " .. tostring(trackers.minimapSender))
  end

  local function test_settings_hook_reaches_the_module()
    local options, runtime, trackers = build({ iconMode = "both" })
    local controller = WindowRuntime.Create(options)
    assert(trackers.coordOptions.getDetachedPreview() == nil, "starts pinned")
    controller.ensureWindow()
    runtime.accountState.settings.widgetPreviewPosition = "detached"
    trackers.windowOptions.onSettingChanged("widgetPreviewPosition", "detached")
    assert(trackers.coordOptions.getDetachedPreview() ~= nil, "choosing Detached creates the surface")
  end

  test_startup_in_mode_none_creates_the_detached_surface()
  test_startup_pinned_creates_no_surface()
  test_active_surface_is_detached_in_both_mode()
  test_active_surface_is_the_widget_when_pinned()
  test_widget_pulse_sees_the_detached_external()
  test_widget_pulse_follows_a_shown_detached_external()
  test_one_card_in_both_mode()
  test_startup_shows_a_pending_whisper_on_the_detached_card()
  test_settings_hook_reaches_the_module()
end
