local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")

local PreviewOpen = {}

-- Opens the messenger on a whisper conversation, over any panel or settings.
-- Same refusals as OpenConversation. runtime members are read at call time:
-- they are bound after the callers are built.
function PreviewOpen.OpenConversation(runtime, selectConversation, conversationKey)
  if conversationKey == nil or Guards.IsRefused(runtime) then
    return
  end

  runtime.ensureWindow()
  runtime.setWindowVisible(true)
  local window = runtime.window
  if window and window.hidePanel then
    window.hidePanel(true)
  end
  -- Settings cover the chat too; close them so the opened chat is on screen.
  local coveredByOptions = window and window.isConversationPaneShown and not window.isConversationPaneShown()
  if coveredByOptions and window.setOptionsVisible then
    window.setOptionsVisible(false, true)
  end
  if window and window.setTabMode then
    window.setTabMode("whispers")
  end
  selectConversation(conversationKey)
end

-- Left-click on the widget or minimap whisper preview: open the messenger on
-- the whisper it shows. Opening the window acknowledges the preview and the
-- selection's refresh clears it.
function PreviewOpen.Create(options)
  local runtime = options.runtime
  local buildContacts = options.buildContacts
  local buildLatestIncomingPreview = options.buildLatestIncomingPreview
  local selectConversation = options.selectConversation

  return function()
    if Guards.IsRefused(runtime) then
      return
    end
    local preview = buildLatestIncomingPreview(buildContacts())
    PreviewOpen.OpenConversation(runtime, selectConversation, preview and preview.conversationKey or nil)
  end
end

ns.BootstrapWindowRuntimePreviewOpen = PreviewOpen

return PreviewOpen
