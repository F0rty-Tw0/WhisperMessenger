-- Composition-only test for WindowRuntime.Create.
--
-- Leaf behavior is owned by the focused submodule tests:
--   * test_window_runtime_bindings.lua          - controller / runtime surface
--   * test_window_runtime_toggle_flow.lua       - toggle / unread routing
--   * test_window_runtime_widget_preview.lua    - preview ack / latest pick
--   * test_window_runtime_window_callbacks.lua  - pin / remove / reorder / send
--   * test_window_runtime_start_conversation.lua- name resolution + create
--   * test_window_runtime_group_send_policy.lua - group send notice + routing
--   * test_window_runtime_icon_runtime.lua      - icon options + position
--   * test_settings_handler.lua                 - per-key onSettingChanged effects
--
-- This file only verifies that WindowRuntime stitches those submodules together
-- correctly: that the controller surface is right, the icon is eager, the
-- window is lazy, and the cross-module wires (setWindowVisible -> widget ack,
-- toggle -> selector, onSettingChanged -> SettingsHandler) survive composition.

local FakeUI = require("tests.helpers.fake_ui")
local WindowRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime")

local function makeRuntimeOptions()
  local conversationKey = "wow::WOW::arthas-area52"

  local runtime = {
    accountState = { settings = {} },
    localProfileId = "me",
    chatApi = {},
    store = {
      conversations = {
        [conversationKey] = {
          conversationKey = conversationKey,
          displayName = "Arthas-Area52",
          channel = "WOW",
          guid = "Player-1-00000001",
          unreadCount = 3,
          messages = {},
        },
      },
      config = {},
    },
  }

  local trackers = {
    iconCreates = 0,
    minimapCreates = 0,
    windowCreates = 0,
    coordinatorVisible = false,
    capturedWindowOptions = nil,
    capturedIconOptions = nil,
    coordinator = nil,
    widgetPreviewInputs = {},
    minimapPreviewInputs = {},
    ldbObject = {},
  }

  local fakeCoordinatorModule = {
    Create = function(coordOptions)
      local coord = {}
      function coord.buildSelectionState(contacts)
        return { selectedContact = contacts[1], conversation = nil, status = nil }
      end
      function coord.refreshWindow()
        local ldbObject = coordOptions.getLdbObject()
        if ldbObject then
          ldbObject.refreshes = (ldbObject.refreshes or 0) + 1
        end
        return nil
      end
      function coord.setWindowVisible(nextVisible)
        trackers.coordinatorVisible = nextVisible
      end
      function coord.isWindowVisible()
        return trackers.coordinatorVisible
      end
      function coord.findLatestUnreadKey()
        local contacts = coordOptions.buildContacts()
        for _, item in ipairs(contacts) do
          if (item.unreadCount or 0) > 0 then
            return item.conversationKey
          end
        end
        return nil
      end
      function coord.scheduleAvailabilityRefresh() end
      trackers.coordinator = coord
      return coord
    end,
  }

  local fakeMessengerWindow = {
    Create = function(_uiFactory, options)
      trackers.windowCreates = trackers.windowCreates + 1
      trackers.capturedWindowOptions = options
      local window = { shown = false }
      window.frame = {
        Show = function(self)
          self.shown = true
        end,
        Hide = function(self)
          self.shown = false
        end,
      }
      window.composer = {
        input = {
          _text = "",
          SetText = function(self, text)
            self._text = text or ""
          end,
          GetText = function(self)
            return self._text
          end,
          SetFocus = function() end,
        },
      }
      window.refreshSelection = function() end
      window.refreshTheme = function() end
      window.setTabMode = function() end
      return window
    end,
  }

  local fakeToggleIcon = {
    Create = function(_uiFactory, options)
      trackers.iconCreates = trackers.iconCreates + 1
      trackers.capturedIconOptions = options
      local iconFrame = {
        parent = {},
        shown = true,
        SetPoint = function(self, anchorPoint, parent, relativePoint, x, y)
          self.point = { anchorPoint, parent, relativePoint, x, y }
        end,
        Show = function(self)
          self.shown = true
        end,
        Hide = function(self)
          self.shown = false
        end,
      }
      trackers.iconFrame = iconFrame
      return {
        frame = iconFrame,
        setUnreadCount = function() end,
        setIncomingPreview = function(senderName, messageText, classTag)
          trackers.widgetPreviewInputs[#trackers.widgetPreviewInputs + 1] = { senderName, messageText, classTag }
        end,
      }
    end,
  }

  -- Real fake frames (stateful Show/Hide/IsShown) so icon-mode visibility is
  -- observable; a wrapper records created frames by name for lookup.
  local fakeFactory = FakeUI.NewFactory()
  local innerCreateFrame = fakeFactory.CreateFrame
  fakeFactory.CreateFrame = function(frameType, name, parent, template)
    local frame = innerCreateFrame(frameType, name, parent, template)
    frame.shown = true -- WoW frames start shown
    if name then
      trackers.framesByName = trackers.framesByName or {}
      trackers.framesByName[name] = frame
    end
    return frame
  end

  local fakeMinimapIconRuntime = {
    Create = function(_options)
      trackers.minimapCreates = trackers.minimapCreates + 1
      local minimapFrame = fakeFactory.CreateFrame("Button", "WhisperMessengerMinimapIcon", nil)
      local minimapIcon = {
        frame = minimapFrame,
        setShown = function(shown)
          if shown then
            minimapFrame:Show()
          else
            minimapFrame:Hide()
            trackers.minimapPreviewInputs[#trackers.minimapPreviewInputs + 1] = { nil, nil, nil }
          end
        end,
        setIncomingPreview = function(senderName, messageText, classTag)
          trackers.minimapPreviewInputs[#trackers.minimapPreviewInputs + 1] = { senderName, messageText, classTag }
        end,
        setUnreadCount = function() end,
      }
      return {
        minimapIcon = minimapIcon,
        getLdbObject = function()
          return trackers.ldbObject
        end,
      }
    end,
  }

  local options = {
    runtime = runtime,
    accountState = runtime.accountState,
    characterState = {
      window = { x = 0, y = 0, width = 900, height = 560 },
      icon = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    },
    defaultCharacterState = {
      window = { x = 10, y = 20, width = 920, height = 580 },
      icon = { anchorPoint = "TOPLEFT", relativePoint = "TOPLEFT", x = 25, y = -40 },
    },
    uiFactory = fakeFactory,
    bootstrap = { _inMythicContent = false },
    contactsList = {
      BuildItemsForProfile = function()
        local convo = runtime.store.conversations[conversationKey]
        return {
          {
            conversationKey = conversationKey,
            displayName = convo.displayName,
            channel = convo.channel,
            guid = convo.guid,
            unreadCount = convo.unreadCount,
          },
        }
      end,
    },
    messengerWindow = fakeMessengerWindow,
    toggleIcon = fakeToggleIcon,
    minimapIconRuntime = fakeMinimapIconRuntime,
    windowCoordinator = fakeCoordinatorModule,
    sendHandler = { HandleSend = function() end },
    tableUtils = {
      copyState = function(value)
        local copy = {}
        for key, nextValue in pairs(value) do
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
    markConversationRead = function(store, key)
      store.conversations[key].unreadCount = 0
    end,
    requestAvailability = function() end,
    trace = function() end,
  }

  return options, runtime, trackers, conversationKey
end

return function()
  local options, runtime, trackers, conversationKey = makeRuntimeOptions()
  local controller = WindowRuntime.Create(options)

  -- Public controller surface (RuntimeBindings owns the leaf assertions).
  for _, name in ipairs({
    "getWindow",
    "getIcon",
    "isWindowVisible",
    "setDiagnostics",
    "buildContacts",
    "ensureWindow",
    "refreshWindow",
    "selectConversation",
    "setWindowVisible",
    "setComposerText",
    "toggle",
  }) do
    assert(type(controller[name]) == "function", "controller should expose " .. name)
  end

  -- Eager icon, lazy window. The icon needs an unread badge before the window
  -- is ever opened; the window is heavy and stays uncreated until needed.
  assert(trackers.iconCreates == 1, "icon should be created eagerly")
  assert(trackers.windowCreates == 0, "window creation should stay lazy")
  assert(runtime.icon ~= nil, "runtime.icon should be wired immediately")
  assert(runtime.window == nil, "runtime.window should stay nil before first ensureWindow")

  -- Runtime exposes the controller's flow methods so external callers (event
  -- bridge, slash commands) can drive the window without reaching into it.
  assert(runtime.toggle == controller.toggle, "runtime.toggle should share controller toggle")
  assert(runtime.refreshWindow == controller.refreshWindow, "runtime.refreshWindow should share controller refresh")
  assert(runtime.ensureWindow == controller.ensureWindow, "runtime.ensureWindow should share controller ensure")
  assert(runtime.setWindowVisible == controller.setWindowVisible, "runtime.setWindowVisible should share controller visibility")
  assert(runtime.setComposerText == controller.setComposerText, "runtime.setComposerText should share controller composer setter")
  assert(type(runtime.isConversationOpen) == "function", "runtime.isConversationOpen should be wired")

  -- Group send policy and availability refresh are exposed for the event bridge.
  assert(type(runtime.getGroupSendNotice) == "function", "runtime.getGroupSendNotice should be wired")
  assert(type(runtime.onAvailabilityChanged) == "function", "runtime.onAvailabilityChanged should be wired")

  -- ensureWindow creates exactly once and routes window options through real
  -- WindowCallbacks / SettingsHandler / StartConversation submodules.
  controller.ensureWindow()
  assert(trackers.windowCreates == 1, "ensureWindow should create the window once")
  controller.ensureWindow()
  assert(trackers.windowCreates == 1, "ensureWindow should be idempotent")
  assert(runtime.window ~= nil, "runtime.window should expose the created window")

  local windowOptions = trackers.capturedWindowOptions
  for _, name in ipairs({
    "onTabModeChanged",
    "onSelectConversation",
    "onStartConversation",
    "onSend",
    "onPositionChanged",
    "onClose",
    "onResetWindowPosition",
    "onClearAllChats",
    "onPin",
    "onRemove",
    "onReorder",
    "onResetIconPosition",
    "onSettingChanged",
  }) do
    assert(type(windowOptions[name]) == "function", "window options should include " .. name)
  end

  -- Composition wire: setWindowVisible(true) must acknowledge the latest widget
  -- preview (covered as a leaf in widget_preview, the composition is the wire).
  options.accountState.conversations = options.accountState.conversations or {}
  options.accountState.conversations[conversationKey] = {
    displayName = "Arthas-Area52",
    channel = "WOW",
    lastIncomingSender = "Arthas-Area52",
    lastIncomingPreview = "Need help?",
    lastIncomingAt = 9999,
  }
  options.accountState.widgetPreviewAcknowledgedAt = nil
  controller.setWindowVisible(true)
  assert(options.accountState.widgetPreviewAcknowledgedAt == 9999, "setWindowVisible(true) should acknowledge the latest widget preview")

  -- Composition wire: toggle() routes through ToggleFlow + real ConversationSelector.
  -- Whispers tab + matching unread key => selector marks unread as read.
  trackers.coordinatorVisible = false
  runtime.store.conversations[conversationKey].unreadCount = 5
  runtime.activeConversationKey = nil
  runtime.window.getTabMode = function()
    return "whispers"
  end
  controller.toggle()
  assert(trackers.coordinatorVisible == true, "toggle should open the window via coordinator")
  assert(runtime.activeConversationKey == conversationKey, "toggle should select the latest unread on Whispers tab")
  assert(runtime.store.conversations[conversationKey].unreadCount == 0, "selecting a conversation should mark it read")

  -- Composition wire: setComposerText writes the real composer.
  controller.setComposerText("draft")
  assert(runtime.window.composer.input:GetText() == "draft", "setComposerText should write the composer input")

  -- Composition wire: onSettingChanged uses the real SettingsHandler. A theme
  -- change should refresh the static window chrome - the wire we care about
  -- here is "the SettingsHandler is actually the one we wired up", not the
  -- per-key behavior (covered in test_settings_handler.lua).
  runtime.window.refreshTheme = function()
    runtime.window._refreshThemeCalls = (runtime.window._refreshThemeCalls or 0) + 1
  end
  windowOptions.onSettingChanged("themePreset", "elvui_dark")
  assert(runtime.accountState.settings.themePreset == "elvui_dark", "settings handler should persist theme change")
  assert((runtime.window._refreshThemeCalls or 0) == 1, "theme change should refresh static chrome via real handler")

  -- Composition wire: default widget mode keeps the widget visible and the
  -- minimap runtime registered for its LDB launcher, but hides its frame.
  local minimapFrame = trackers.framesByName and trackers.framesByName["WhisperMessengerMinimapIcon"]
  assert(minimapFrame ~= nil, "the minimap runtime should initialize in default widget mode")
  assert(trackers.minimapCreates == 1, "default widget mode should register the minimap runtime once")
  assert(minimapFrame:IsShown() == false, "default widget mode should hide the minimap frame")
  assert(trackers.iconFrame.shown == true, "widget icon should start visible in default widget mode")

  local ldbRefreshes = trackers.ldbObject.refreshes or 0
  controller.refreshWindow()
  runtime.refreshWindow()
  assert(trackers.ldbObject.refreshes == ldbRefreshes + 2, "widget-mode refresh paths should update the registered LDB launcher")

  windowOptions.onSettingChanged("iconMode", "minimap")
  minimapFrame = trackers.framesByName and trackers.framesByName["WhisperMessengerMinimapIcon"]
  assert(trackers.minimapCreates == 1, "minimap runtime should be created when minimap mode is selected")
  assert(trackers.iconFrame.shown == false, "widget icon should hide in minimap mode")
  assert(minimapFrame:IsShown() == true, "minimap icon should show in minimap mode")

  windowOptions.onSettingChanged("iconMode", "both")
  assert(trackers.iconFrame.shown == true, "widget icon should show in both mode")
  assert(minimapFrame:IsShown() == true, "minimap icon should stay shown in both mode")

  windowOptions.onSettingChanged("iconMode", "none")
  assert(trackers.iconFrame.shown == false, "widget icon should hide in none mode")
  assert(minimapFrame:IsShown() == false, "minimap icon should hide in none mode")
  assert(trackers.widgetPreviewInputs[#trackers.widgetPreviewInputs][1] == nil, "none mode should clear widget preview")

  -- Startup none mode must not allocate either icon surface.
  do
    local noneOptions, noneRuntime, noneTrackers = makeRuntimeOptions()
    noneOptions.accountState.settings.iconMode = "none"
    local noneController = WindowRuntime.Create(noneOptions)
    assert(noneTrackers.iconCreates == 0, "none mode should not create the widget icon at startup")
    assert(noneTrackers.minimapCreates == 0, "none mode should not create the minimap icon at startup")
    assert(noneRuntime.icon == nil, "none mode should leave runtime.icon unset")
    noneController.ensureWindow()
    noneTrackers.capturedWindowOptions.onSettingChanged("iconMode", "widget")
    assert(noneRuntime.icon ~= nil, "switching from none to widget should expose the created icon on runtime")
  end

  -- Startup sharing seeds account storage immediately even when the selected
  -- mode does not allocate the draggable widget.
  for _, mode in ipairs({ "none", "minimap" }) do
    local sharingOptions, sharingRuntime, sharingTrackers = makeRuntimeOptions()
    local localPosition = sharingOptions.characterState.icon
    sharingOptions.accountState.settings.iconMode = mode
    sharingOptions.accountState.settings.shareWidgetPosition = true

    WindowRuntime.Create(sharingOptions)

    local sharedPosition = sharingOptions.accountState.sharedWidgetPosition
    assert(sharedPosition ~= nil, mode .. " startup should seed the shared widget position immediately")
    assert(sharedPosition ~= localPosition, mode .. " startup should copy rather than alias the character position")
    assert(
      sharedPosition.anchorPoint == "CENTER" and sharedPosition.relativePoint == "CENTER" and sharedPosition.x == 0 and sharedPosition.y == 0,
      mode .. " startup should seed the exact character position"
    )
    assert(sharingTrackers.iconCreates == 0, mode .. " startup sharing should not allocate the draggable widget")
    assert(sharingRuntime.icon == nil, mode .. " startup sharing should leave runtime.icon unset")
  end

  -- Enabling sharing seeds the account slot from the current character
  -- position and reapplies those same coordinates without a visible jump.
  do
    local sharingOptions, _, sharingTrackers = makeRuntimeOptions()
    local localPosition = sharingOptions.characterState.icon
    local sharingController = WindowRuntime.Create(sharingOptions)
    sharingController.ensureWindow()

    sharingTrackers.capturedWindowOptions.onSettingChanged("shareWidgetPosition", true)

    local sharedPosition = sharingOptions.accountState.sharedWidgetPosition
    assert(sharedPosition ~= nil, "enabling sharing should seed the account position")
    assert(sharedPosition ~= localPosition, "enabling sharing should copy rather than alias the character position")
    assert(
      sharedPosition.anchorPoint == "CENTER" and sharedPosition.relativePoint == "CENTER" and sharedPosition.x == 0 and sharedPosition.y == 0,
      "enabling sharing should seed the exact current character position"
    )
    assert(sharingOptions.characterState.icon == localPosition, "enabling sharing should preserve the character position")
    local appliedPoint = sharingTrackers.iconFrame.point
    assert(
      appliedPoint
        and appliedPoint[1] == "CENTER"
        and appliedPoint[2] == sharingTrackers.iconFrame.parent
        and appliedPoint[3] == "CENTER"
        and appliedPoint[4] == 0
        and appliedPoint[5] == 0,
      "enabling sharing should reapply the same position without moving the widget"
    )
  end

  -- Disabling sharing restores the untouched character position to the frame.
  do
    local sharingOptions, _, sharingTrackers = makeRuntimeOptions()
    local localPosition = sharingOptions.characterState.icon
    local sharedPosition = { anchorPoint = "TOP", relativePoint = "TOP", x = 70, y = -80 }
    sharingOptions.accountState.settings.shareWidgetPosition = true
    sharingOptions.accountState.sharedWidgetPosition = sharedPosition
    local sharingController = WindowRuntime.Create(sharingOptions)
    sharingController.ensureWindow()
    sharingTrackers.iconFrame:SetPoint(
      sharedPosition.anchorPoint,
      sharingTrackers.iconFrame.parent,
      sharedPosition.relativePoint,
      sharedPosition.x,
      sharedPosition.y
    )

    sharingTrackers.capturedWindowOptions.onSettingChanged("shareWidgetPosition", false)

    local appliedPoint = sharingTrackers.iconFrame.point
    assert(
      appliedPoint[1] == "CENTER"
        and appliedPoint[2] == sharingTrackers.iconFrame.parent
        and appliedPoint[3] == "CENTER"
        and appliedPoint[4] == 0
        and appliedPoint[5] == 0,
      "disabling sharing should apply the exact character position"
    )
    assert(sharingOptions.characterState.icon == localPosition, "disabling sharing should preserve the character position")
  end

  -- Sharing transitions in none and minimap-only modes update storage without
  -- allocating the draggable widget.
  for _, mode in ipairs({ "none", "minimap" }) do
    local sharingOptions, sharingRuntime, sharingTrackers = makeRuntimeOptions()
    local localPosition = sharingOptions.characterState.icon
    sharingOptions.accountState.settings.iconMode = mode
    local sharingController = WindowRuntime.Create(sharingOptions)
    sharingController.ensureWindow()

    sharingTrackers.capturedWindowOptions.onSettingChanged("shareWidgetPosition", true)

    local sharedPosition = sharingOptions.accountState.sharedWidgetPosition
    assert(sharedPosition ~= nil, mode .. " sharing transition should seed the account position")
    assert(sharedPosition ~= localPosition, mode .. " sharing transition should copy the character position")
    assert(
      sharedPosition.anchorPoint == "CENTER" and sharedPosition.relativePoint == "CENTER" and sharedPosition.x == 0 and sharedPosition.y == 0,
      mode .. " sharing transition should persist the exact character position"
    )
    assert(sharingTrackers.iconCreates == 0, mode .. " sharing transition should not create the widget")
    assert(sharingRuntime.icon == nil, mode .. " sharing transition should leave runtime.icon unset")
  end
  assert(trackers.minimapPreviewInputs[#trackers.minimapPreviewInputs][1] == nil, "none mode should clear minimap preview")
end
