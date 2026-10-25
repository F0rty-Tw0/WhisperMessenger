local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")

local PreviewOpen = {}

-- Left-click on the widget or minimap whisper preview: open the messenger on
-- the whisper it shows. Same refusals as OpenConversation. Opening the window
-- acknowledges the preview and the selection's refresh clears it. runtime
-- members are read at click time: they are bound after this is built.
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
    local conversationKey = preview and preview.conversationKey or nil
    if conversationKey == nil then
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
end

ns.BootstrapWindowRuntimePreviewOpen = PreviewOpen

return PreviewOpen
