local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ToggleFlow = ns.BootstrapWindowRuntimeToggleFlow or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ToggleFlow")
local IconToggle = ns.BootstrapWindowRuntimeIconToggle or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconToggle")
local PreviewOpen = ns.BootstrapWindowRuntimePreviewOpen or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PreviewOpen")
local PreviewReplyRuntime = ns.BootstrapWindowRuntimePreviewReplyRuntime
  or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PreviewReplyRuntime")

-- Builds what the icon surfaces and the key bindings start: the window toggle,
-- the icon click, the preview open and the reply under a preview.
local Flows = {}

-- options: runtime, accountState, windowCallbacks, buildContacts,
-- buildLatestIncomingPreview, acknowledgeLatestWidgetPreview,
-- acknowledgeWidgetPreviewThrough, ensureWindow, isWindowVisible,
-- setWindowVisible, getWindow, findLatestUnreadKey, selectConversation,
-- refreshWindow.
-- Returns toggle and openTargetKey (see ToggleFlow) and surfaceHandlers, the
-- table Surfaces.setHandlers takes.
function Flows.Create(options)
  local runtime = options.runtime
  local windowCallbacks = options.windowCallbacks
  local buildContacts = options.buildContacts
  local selectConversation = options.selectConversation
  local refreshWindow = options.refreshWindow

  local toggleFlow = ToggleFlow.Create({
    runtime = runtime,
    ensureWindow = options.ensureWindow,
    isWindowVisible = options.isWindowVisible,
    setWindowVisible = options.setWindowVisible,
    getWindow = options.getWindow,
    findLatestUnreadKey = options.findLatestUnreadKey,
    selectConversation = selectConversation,
    refreshWindow = refreshWindow,
  })
  local toggle = toggleFlow.toggle
  local onIconToggle = IconToggle.Wrap(runtime, toggle, buildContacts, toggleFlow.openTargetKey)
  local onOpenPreview = PreviewOpen.Create({
    runtime = runtime,
    buildContacts = buildContacts,
    buildLatestIncomingPreview = options.buildLatestIncomingPreview,
    selectConversation = selectConversation,
  })
  local previewReply = PreviewReplyRuntime.Create({
    runtime = runtime,
    accountState = options.accountState,
    buildContacts = buildContacts,
    onSend = windowCallbacks.onSend,
    setDraft = windowCallbacks.onDraftChanged,
    acknowledgeThrough = options.acknowledgeWidgetPreviewThrough,
    refreshWindow = refreshWindow,
    openConversation = onOpenPreview,
  })

  return {
    toggle = toggle,
    openTargetKey = toggleFlow.openTargetKey,
    surfaceHandlers = {
      onToggle = onIconToggle,
      onOpenPreview = onOpenPreview,
      onMarkAllRead = windowCallbacks.onMarkAllRead,
      quickReply = previewReply.quickReply,
      acknowledgeLatestWidgetPreview = options.acknowledgeLatestWidgetPreview,
      refreshWindow = refreshWindow,
    },
  }
end

ns.BootstrapWindowRuntimeFlows = Flows
return Flows
