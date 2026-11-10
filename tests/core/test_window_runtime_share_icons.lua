-- Composition test: toggling "share widget position" moves the widget, the
-- minimap button and the detached preview live, with no /reload. Oracle: the State x event table of the
-- "Same position on every character" spec (toggle off: back to this
-- character's spot; toggle on: A = copy(P), so nothing jumps).

local FakeUI = require("tests.helpers.fake_ui")
local WindowRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime")

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
      function coord.updateIconSurfaces() end
      return coord
    end,
  }
end

-- The widget's frame records every SetPoint it receives.
local function fakeToggleIcon(trackers)
  local noop = function() end
  return {
    Create = function(_uiFactory, options)
      trackers.capturedIconOptions = options
      return {
        frame = {
          SetPoint = function(_self, ...)
            trackers.widgetPoints[#trackers.widgetPoints + 1] = { ... }
          end,
          Show = noop,
          Hide = noop,
        },
        setUnreadCount = noop,
        setIncomingPreview = noop,
        refreshTheme = noop,
      }
    end,
  }
end

-- The minimap button records every state applyRadialPosition receives.
local function fakeMinimapIconRuntime(trackers, factory)
  local noop = function() end
  return {
    Create = function()
      return {
        minimapIcon = {
          frame = factory.CreateFrame("Button", nil, nil),
          setShown = noop,
          setIncomingPreview = noop,
          setUnreadCount = noop,
          refreshTheme = noop,
          applyRadialPosition = function(state)
            trackers.minimapApplied[#trackers.minimapApplied + 1] = state
          end,
        },
        getLdbObject = function()
          return {}
        end,
      }
    end,
  }
end

local function build(accountExtras, characterState)
  local accountState = { settings = { iconMode = "both", shareWidgetPosition = true } }
  for key, value in pairs(accountExtras) do
    accountState[key] = value
  end
  local runtime = { accountState = accountState, localProfileId = "me", chatApi = {}, store = { conversations = {}, config = {} } }
  local trackers = { widgetPoints = {}, minimapApplied = {} }
  local factory = FakeUI.NewFactory()
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  uiParent:Show()

  local options = {
    runtime = runtime,
    accountState = accountState,
    characterState = characterState,
    defaultCharacterState = { window = {}, icon = {} },
    uiFactory = factory,
    uiParent = uiParent,
    bootstrap = { _inMythicContent = false },
    contactsList = {
      BuildItemsForProfile = function()
        return {}
      end,
    },
    messengerWindow = {
      Create = function(_factory, windowOptions)
        trackers.windowOptions = windowOptions
        return { frame = factory.CreateFrame("Frame", nil, nil), applySavedState = function() end }
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
  return options, accountState, trackers
end

local function makeCharacterState()
  return {
    window = {},
    icon = { anchorPoint = "TOP", relativePoint = "TOP", x = 11, y = -22 },
    minimapIcon = { degrees = 45 },
  }
end

-- The settings handler saves the value itself, as the Icons page does.
local function toggleSharing(trackers, enabled)
  trackers.windowOptions.onSettingChanged("shareWidgetPosition", enabled)
end

return function()
  local function test_toggle_off_moves_the_minimap_button_back_to_this_characters_angle_live()
    local options, _, trackers = build({ sharedMinimapIcon = { degrees = 200 } }, makeCharacterState())
    local controller = WindowRuntime.Create(options)
    controller.ensureWindow()

    toggleSharing(trackers, false)

    local applied = trackers.minimapApplied[#trackers.minimapApplied]
    assert(applied ~= nil, "the minimap button is re-applied on the toggle")
    assert(applied.degrees == 45, "the button returns to this character's angle; got " .. tostring(applied.degrees))
  end

  local function test_reset_to_defaults_with_sharing_off_moves_nothing()
    local characterState = makeCharacterState()
    local options, accountState, trackers = build({}, characterState)
    accountState.settings.shareWidgetPosition = false
    local controller = WindowRuntime.Create(options)
    controller.ensureWindow()

    local minimapBefore, widgetBefore = #trackers.minimapApplied, #trackers.widgetPoints

    toggleSharing(trackers, false)
    toggleSharing(trackers, false)

    assert(#trackers.minimapApplied == minimapBefore, "an unchanged setting never re-applies the minimap button")
    assert(#trackers.widgetPoints == widgetBefore, "an unchanged setting never re-applies the widget")
    assert(accountState.sharedMinimapIcon == nil and accountState.sharedWidgetPosition == nil, "no account spot is written")
  end

  local function test_toggle_off_moves_the_detached_preview_back_to_this_characters_spot_live()
    local characterState = makeCharacterState()
    characterState.detachedPreview = { x = 10, y = -20 }
    local options, accountState, trackers = build({ sharedDetachedPreview = { x = 300, y = -400 } }, characterState)
    accountState.settings.widgetPreviewPosition = "detached"
    local controller = WindowRuntime.Create(options)
    controller.ensureWindow()
    local holder = trackers.coordOptions.getDetachedPreview().previewFrame:GetParent()
    local _, _, _, sharedX, sharedY = holder:GetPoint()
    assert(sharedX == 300 and sharedY == -400, "the preview starts at the account spot")

    toggleSharing(trackers, false)

    local point, _, relativePoint, x, y = holder:GetPoint()
    assert(point == "TOP" and relativePoint == "TOP", "the preview stays anchored to the top")
    assert(x == 10 and y == -20, "the preview returns to this character's spot; got " .. tostring(x) .. ", " .. tostring(y))
  end

  test_toggle_off_moves_the_minimap_button_back_to_this_characters_angle_live()
  test_reset_to_defaults_with_sharing_off_moves_nothing()
  test_toggle_off_moves_the_detached_preview_back_to_this_characters_spot_live()
end
