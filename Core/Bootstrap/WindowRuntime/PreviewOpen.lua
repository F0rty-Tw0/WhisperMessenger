local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")
local WhoTriggers = ns.BootstrapWindowRuntimeWhoTriggers or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WhoTriggers")

local PreviewOpen = {}

-- Left-click on the widget or minimap whisper preview: open the messenger on
-- the whisper it shows. Same refusals as OpenConversation. Opening the window
-- acknowledges the preview and the selection's refresh clears it. runtime
-- members are read at click time: they are bound after this is built.
-- An explicit conversationKey (the reply card's held chat) wins over the
-- latest preview. Returns true when the chat was opened.
function PreviewOpen.Create(options)
  local runtime = options.runtime
  local buildContacts = options.buildContacts
  local buildLatestIncomingPreview = options.buildLatestIncomingPreview
  local selectConversation = options.selectConversation

  return function(conversationKey)
    if Guards.IsRefused(runtime) then
      return false
    end

    if conversationKey == nil then
      local preview = buildLatestIncomingPreview(buildContacts())
      conversationKey = preview and preview.conversationKey or nil
    end
    if conversationKey == nil then
      return false
    end

    -- A click on a preview card is a hardware event: ask /who inside it, before
    -- the window opens. Asked after the open, the game blocked SendWho.
    WhoTriggers.AskFor(runtime, conversationKey)
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
    return true
  end
end

ns.BootstrapWindowRuntimePreviewOpen = PreviewOpen

return PreviewOpen
