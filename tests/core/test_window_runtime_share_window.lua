-- Composition test: with "Same position on every character" on, the messenger
-- window (classic and compact) opens at the account spot and moves live when
-- the option is toggled. Oracle: the State x event table of the spec.

local FakeUI = require("tests.helpers.fake_ui")
local WindowRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime")
local Theme = require("WhisperMessenger.UI.Theme")
local WindowSizing = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowSizing")

local function fakeCoordinatorModule()
  return {
    Create = function()
      local visible = false
      local coord = {}
      function coord.buildSelectionState(contacts)
        return { selectedContact = contacts[1], conversation = nil, status = nil }
      end
      function coord.refreshWindow() end
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

-- iconMode "none": no widget or minimap button, so only the window moves.
local function build(accountExtras, characterState, compactLayout)
  local accountState = { settings = { iconMode = "none", shareWidgetPosition = true, compactLayout = compactLayout } }
  for key, value in pairs(accountExtras) do
    accountState[key] = value
  end
  characterState.icon = characterState.icon or { anchorPoint = "TOP", relativePoint = "TOP", x = 1, y = -2 }
  characterState.minimapIcon = characterState.minimapIcon or { degrees = 45 }
  local runtime = { accountState = accountState, localProfileId = "me", chatApi = {}, store = { conversations = {}, config = {} } }
  local trackers = { applied = {} }
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
        return {
          frame = factory.CreateFrame("Frame", nil, nil),
          applySavedState = function(state)
            trackers.applied[#trackers.applied + 1] = state
          end,
        }
      end,
    },
    windowCoordinator = fakeCoordinatorModule(),
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

-- The settings handler saves the value itself, as the Icons page does.
local function toggleSharing(trackers, enabled)
  trackers.windowOptions.onSettingChanged("shareWidgetPosition", enabled)
end

local function lastApplied(trackers)
  return trackers.applied[#trackers.applied]
end

return function()
  local function test_toggle_off_moves_an_open_classic_window_back_to_this_characters_spot()
    local characterState = { window = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 100, y = -10, width = 800, height = 500 } }
    local sharedWindow = { anchorPoint = "TOPLEFT", relativePoint = "TOPLEFT", x = 400, y = -40, width = 900, height = 600 }
    local options, _, trackers = build({ sharedWindow = sharedWindow }, characterState, false)
    local controller = WindowRuntime.Create(options)
    controller.ensureWindow()
    assert(trackers.windowOptions.state.x == 400, "the window opens at the account spot first")

    toggleSharing(trackers, false)

    local applied = lastApplied(trackers)
    assert(applied ~= nil, "the open window is moved on the toggle")
    assert(applied.x == 100 and applied.anchorPoint == "CENTER", "back to this character's spot; got " .. tostring(applied.x))
    assert(applied.width == 800, "this character's size comes back too; got " .. tostring(applied.width))
  end

  local function test_toggle_off_moves_an_open_compact_window_back_to_this_characters_spot()
    local characterState = { window = {}, compactWindow = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 100, y = 0, width = 360 } }
    local options, _, trackers = build({ sharedCompactWindow = { x = 400, width = 420 } }, characterState, true)
    local controller = WindowRuntime.Create(options)
    controller.ensureWindow()

    toggleSharing(trackers, false)

    local applied = lastApplied(trackers)
    assert(applied ~= nil and applied.x == 100 and applied.width == 360, "the compact window gets its own compact spot, not the classic one")
  end

  local function test_toggle_on_keeps_an_open_window_where_it_is()
    local characterState = { window = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 100, y = -10, width = 800, height = 500 } }
    local options, accountState, trackers = build({}, characterState, false)
    accountState.settings.shareWidgetPosition = false
    local controller = WindowRuntime.Create(options)
    controller.ensureWindow()

    toggleSharing(trackers, true)

    local applied = lastApplied(trackers)
    assert(applied ~= nil and applied.x == 100 and applied.width == 800, "the account spot is this character's spot: no jump")
    assert(accountState.sharedWindow.x == 100, "the account spot now holds this character's spot")
  end

  -- The Icons page's Reset to Defaults sends every toggle's default, changed or not.
  local function test_reset_to_defaults_while_sharing_is_off_leaves_the_window_alone()
    local characterState = { window = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 100, y = -10, width = 800, height = 500 } }
    local options, accountState, trackers = build({}, characterState, false)
    accountState.settings.shareWidgetPosition = false
    WindowRuntime.Create(options).ensureWindow()

    toggleSharing(trackers, false)
    toggleSharing(trackers, false)

    assert(#trackers.applied == 0, "an unchanged setting moves nothing; applies: " .. tostring(#trackers.applied))
  end

  local function test_new_character_with_sharing_opens_the_window_at_the_account_spot()
    local characterState = { window = { x = 0, y = 0, width = 900, height = 560, contactsCollapsed = true } }
    local shared = { anchorPoint = "TOPLEFT", relativePoint = "TOPLEFT", x = 400, y = -40, width = 700, height = 500, contactsWidth = 240 }
    local options, _, trackers = build({ sharedWindow = shared }, characterState, false)
    WindowRuntime.Create(options).ensureWindow()

    local state = trackers.windowOptions.state
    assert(state.x == 400 and state.anchorPoint == "TOPLEFT", "the window opens at the account point; got " .. tostring(state.x))
    assert(state.width == 700 and state.height == 500 and state.contactsWidth == 240, "size and list width come from the account spot")
    assert(state.contactsCollapsed == true, "this character's collapsed rail is kept")
  end

  local function test_new_character_with_sharing_opens_the_compact_window_at_the_account_spot()
    local options, _, trackers = build(
      { sharedCompactWindow = { anchorPoint = "TOP", relativePoint = "TOP", x = 7, y = -9, width = 420 } },
      { window = {} },
      true
    )
    WindowRuntime.Create(options).ensureWindow()

    local state = trackers.windowOptions.state
    assert(state.x == 7 and state.width == 420, "the compact window opens at the account spot; got " .. tostring(state.x))
  end

  local function test_narrow_shared_width_is_widened_for_a_character_with_an_open_rail()
    local characterState = { window = { contactsCollapsed = false } }
    local options, _, trackers =
      build({ sharedWindow = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 400, height = 500 } }, characterState, false)
    WindowRuntime.Create(options).ensureWindow()

    local parent = {
      GetWidth = function()
        return 1920
      end,
      GetHeight = function()
        return 1080
      end,
    }
    local initial = WindowSizing.InitialState(parent, trackers.windowOptions.state, 1, false)
    assert(
      initial.width >= Theme.LAYOUT.WINDOW_MIN_WIDTH,
      "a width saved with a collapsed rail still fits this character's open rail; got " .. tostring(initial.width)
    )
  end

  test_toggle_off_moves_an_open_classic_window_back_to_this_characters_spot()
  test_toggle_off_moves_an_open_compact_window_back_to_this_characters_spot()
  test_toggle_on_keeps_an_open_window_where_it_is()
  test_reset_to_defaults_while_sharing_is_off_leaves_the_window_alone()
  test_new_character_with_sharing_opens_the_window_at_the_account_spot()
  test_new_character_with_sharing_opens_the_compact_window_at_the_account_spot()
  test_narrow_shared_width_is_widened_for_a_character_with_an_open_rail()
end
