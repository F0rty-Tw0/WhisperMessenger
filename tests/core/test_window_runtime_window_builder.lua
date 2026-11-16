-- WindowBuilder builds the messenger window on first need: the settings
-- handler, the window options, the window itself, the panel registry binding
-- and the hide hook, in that order.

local FakeUI = require("tests.helpers.fake_ui")
local WindowBuilder = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowBuilder")

local function noop() end

local function fakeSurfaces()
  return {
    getIcon = noop,
    getMinimap = noop,
    getWidgetIcon = noop,
    applyIconMode = noop,
    refreshTheme = noop,
    ensureDetachedPreview = noop,
  }
end

-- log: the order things happen in. acks: the contacts each acknowledge got.
local function build(overrides)
  local log, acks = {}, {}
  local contacts = { { conversationKey = "wow::WOW::arthas-area52" } }
  local factory = FakeUI.NewFactory()
  local captured = {}
  local runtime
  runtime = {
    store = { config = {} },
    panelRegistry = {
      bind = function(window)
        captured.boundWindow = window
        captured.runtimeWindowSetAtBind = runtime.window ~= nil
        log[#log + 1] = "bind"
      end,
    },
  }
  local options = {
    runtime = runtime,
    accountState = { settings = { compactLayout = false } },
    characterState = {},
    uiFactory = factory,
    positionSlots = {
      read = function(slot)
        captured.slot = slot
        return { slot = slot }
      end,
    },
    theme = {},
    fonts = {},
    surfaces = fakeSurfaces(),
    coordinator = {
      buildSelectionState = function(builtContacts)
        captured.selectionContacts = builtContacts
        return { selectedContact = builtContacts[1], conversation = "conversation", status = "status" }
      end,
      updateIconSurfaces = noop,
    },
    windowCallbacks = { onSend = noop, onClose = noop },
    externalPreview = {},
    messengerWindow = {
      Create = function(uiFactory, windowOptions)
        captured.uiFactory = uiFactory
        captured.windowOptions = windowOptions
        log[#log + 1] = "create"
        local frame = factory.CreateFrame("Frame", nil, nil)
        frame:Show()
        return { frame = frame }
      end,
    },
    buildContacts = function()
      return contacts
    end,
    selectConversation = noop,
    isWindowVisible = function()
      return false
    end,
    acknowledgeLatestWidgetPreview = function(ackContacts)
      acks[#acks + 1] = ackContacts
    end,
    onShareWidgetPositionChanged = noop,
    onSettingsHandler = function(onSettingChanged)
      captured.onSettingChanged = onSettingChanged
      log[#log + 1] = "settings"
    end,
    onWindowCreated = function(window)
      captured.createdWindow = window
      log[#log + 1] = "created"
    end,
  }
  for key, value in pairs(overrides or {}) do
    options[key] = value
  end
  local window = WindowBuilder.Build(options)
  return { window = window, runtime = runtime, options = options, captured = captured, log = log, acks = acks, contacts = contacts }
end

return function()
  local function test_build_hands_out_the_settings_handler_then_the_window_then_binds_panels()
    local built = build()

    assert(table.concat(built.log, ",") == "settings,create,created,bind", "order, got " .. table.concat(built.log, ","))
    assert(built.captured.createdWindow == built.window, "the caller is handed the new window")
    assert(built.captured.boundWindow == built.window, "the panel registry binds the new window")
    assert(built.runtime.window == built.window, "runtime.window is the new window")
    assert(built.captured.uiFactory == built.options.uiFactory, "the window is created on the ui factory")
  end

  local function test_runtime_window_is_still_unset_while_the_panel_registry_binds()
    local built = build()

    assert(built.captured.runtimeWindowSetAtBind == false, "runtime.window is nil during bind")
  end

  local function test_the_window_gets_the_settings_handler_handed_to_the_caller()
    local built = build()

    assert(type(built.captured.onSettingChanged) == "function", "a settings handler is handed out")
    assert(built.captured.windowOptions.onSettingChanged == built.captured.onSettingChanged, "the window changes settings through it")
  end

  local function test_the_new_window_starts_hidden_without_an_acknowledge()
    local built = build()

    assert(built.window.frame:IsShown() == false, "the new window starts hidden")
    assert(#built.acks == 0, "building acknowledges nothing, got " .. #built.acks)
  end

  -- ESC and the game's close-all hide the frame without the toggle.
  local function test_every_later_frame_hide_acknowledges_the_widget_preview()
    local built = build()
    built.window.frame:Show()

    built.window.frame:Hide()

    assert(#built.acks == 1, "one hide acknowledges once, got " .. #built.acks)
    assert(built.acks[1] == built.contacts, "with the current contacts")
  end

  local function test_the_window_opens_on_the_coordinator_selection()
    local built = build()
    local windowOptions = built.captured.windowOptions

    assert(built.captured.selectionContacts == built.contacts, "the selection is built from the contacts")
    assert(windowOptions.contacts == built.contacts, "the window gets the contacts")
    assert(windowOptions.selectedContact == built.contacts[1], "the window gets the selected contact")
    assert(windowOptions.conversation == "conversation" and windowOptions.status == "status", "and its conversation and status")
  end

  local function test_window_callbacks_pass_straight_through()
    local built = build()

    for name, callback in pairs(built.options.windowCallbacks) do
      assert(built.captured.windowOptions[name] == callback, name .. " reaches the window")
    end
  end

  local function test_the_window_style_picks_the_position_slot()
    local classic = build()
    assert(classic.captured.slot == "window", "the classic window reads its slot, got " .. tostring(classic.captured.slot))
    assert(classic.runtime.compactLayoutActive == false, "the runtime knows the classic window is up")
    assert(classic.captured.windowOptions.compactLayout == false, "the window is told its style")

    local compact = build({ accountState = { settings = {} } })
    assert(compact.captured.slot == "compactWindow", "the compact window reads its slot, got " .. tostring(compact.captured.slot))
    assert(compact.runtime.compactLayoutActive == true, "the runtime knows the compact window is up")
    assert(compact.captured.windowOptions.state.slot == "compactWindow", "the window gets the slot's state")
  end

  local function test_missing_settings_are_created_and_shared_with_the_window()
    local accountState = {}
    local built = build({ accountState = accountState })

    assert(type(accountState.settings) == "table", "the settings table is created")
    assert(built.captured.windowOptions.settingsConfig == accountState.settings, "the window edits the same table")
  end

  test_build_hands_out_the_settings_handler_then_the_window_then_binds_panels()
  test_runtime_window_is_still_unset_while_the_panel_registry_binds()
  test_the_window_gets_the_settings_handler_handed_to_the_caller()
  test_the_new_window_starts_hidden_without_an_acknowledge()
  test_every_later_frame_hide_acknowledges_the_widget_preview()
  test_the_window_opens_on_the_coordinator_selection()
  test_window_callbacks_pass_straight_through()
  test_the_window_style_picks_the_position_slot()
  test_missing_settings_are_created_and_shared_with_the_window()
end
