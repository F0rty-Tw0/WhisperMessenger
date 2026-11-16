local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationSelector = ns.BootstrapWindowRuntimeConversationSelector
  or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ConversationSelector")
local StartConversation = ns.BootstrapWindowRuntimeStartConversation or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.StartConversation")
local WindowCallbacks = ns.BootstrapWindowRuntimeWindowCallbacks or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")
local LivePresenceSender = ns.BootstrapLivePresenceSender or require("WhisperMessenger.Core.Bootstrap.LivePresenceSender")
local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")

-- Builds what drives the window: showing and hiding it, refreshing it,
-- selecting and starting a conversation, and the window callbacks that act
-- through those.
local WindowActions = {}

-- showOptions: see WindowCoordinator.setWindowVisible.
local function createSetWindowVisible(options)
  local runtime = options.runtime
  return function(nextVisible, showOptions)
    -- Acknowledge on both open and close: a whisper that arrived while the
    -- window was open was already on screen, so closing must not let the
    -- next background refresh pop it on the widget as if it were new.
    options.acknowledgeLatestWidgetPreview(options.buildContacts())
    -- Reopening shows the "New messages" divider again only if new
    -- whispers arrived meanwhile.
    if not nextVisible then
      runtime.unreadDivider = nil
    else
      -- Any open during combat hands visibility back to the player: combat
      -- end must not undo a close they make afterwards.
      runtime.hiddenByCombat = nil
    end
    return options.coordinator.setWindowVisible(nextVisible, showOptions)
  end
end

local function createWindowCallbacks(options, actions)
  return WindowCallbacks.Create({
    positionSlots = options.positionSlots,
    runtime = options.runtime,
    accountState = options.accountState,
    characterState = options.characterState,
    defaultCharacterState = options.defaultCharacterState,
    uiParent = options.uiParent,
    getIcon = options.getIcon,
    tableUtils = options.tableUtils,
    groupSendPolicy = options.groupSendPolicy,
    sendHandler = options.sendHandler,
    reactionHandler = options.reactionHandler,
    livePresenceSender = LivePresenceSender,
    refreshWindow = actions.refreshWindow,
    buildContacts = options.buildContacts,
    selectConversation = actions.selectConversation,
    startConversation = actions.startConversation,
    setWindowVisible = actions.setWindowVisible,
    dismissWidgetPreview = function()
      options.acknowledgeLatestWidgetPreview(options.buildContacts())
    end,
  })
end

-- options: runtime, accountState, characterState, defaultCharacterState,
-- uiParent, tableUtils, positionSlots, coordinator, presenceCache,
-- groupSendPolicy, sendHandler, reactionHandler, markConversationRead,
-- requestAvailability, getIcon, getWindow, buildContacts,
-- acknowledgeLatestWidgetPreview.
-- Returns setWindowVisible, refreshWindow, selectConversation,
-- startConversation and windowCallbacks.
function WindowActions.Create(options)
  local runtime = options.runtime
  local coordinator = options.coordinator
  local actions = { setWindowVisible = createSetWindowVisible(options) }

  function actions.refreshWindow(affectedConversationKey, dirtyKeys)
    return coordinator.refreshWindow(affectedConversationKey, dirtyKeys)
  end

  local conversationSelector = ConversationSelector.Create({
    runtime = runtime,
    characterState = options.characterState,
    markConversationRead = options.markConversationRead,
    presenceCache = options.presenceCache,
    requestAvailability = options.requestAvailability,
    refreshWindow = actions.refreshWindow,
  })
  function actions.selectConversation(conversationKey)
    return conversationSelector.selectConversation(conversationKey)
  end

  local startConversationFlow = StartConversation.Create({
    runtime = runtime,
    identity = Identity,
    getWindow = options.getWindow,
    selectConversation = actions.selectConversation,
  })
  actions.startConversation = startConversationFlow.startConversation

  actions.windowCallbacks = createWindowCallbacks(options, actions)
  return actions
end

ns.BootstrapWindowRuntimeWindowActions = WindowActions
return WindowActions
