local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")
local SendHandler = ns.BootstrapSendHandler or require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

local PreviewReplyRuntime = {}

local function findContact(contacts, conversationKey)
  for _, contact in ipairs(contacts or {}) do
    if contact.conversationKey == conversationKey then
      return contact
    end
  end
  return nil
end

-- Same fields as the composer's send, built from the contact (not the
-- preview), so channel, BN ids and guid always match the window's send.
local function buildPayload(contact, text)
  return {
    conversationKey = contact.conversationKey,
    target = contact.displayName,
    displayName = contact.displayName,
    channel = contact.channel,
    bnetAccountID = contact.bnetAccountID,
    conversationID = contact.conversationID,
    guid = contact.guid,
    gameAccountName = contact.gameAccountName,
    text = text,
  }
end

-- Runtime side of the reply row under the widget / minimap whisper preview.
-- meta is the preview table ({ conversationKey, sentAt, channel }). submit
-- never checks Guards.IsRefused: a reply in combat with the window closed is
-- the main use, and under a lock the send path queues the message instead.
-- Nothing here opens the window except open().
function PreviewReplyRuntime.Create(options)
  local runtime = options.runtime
  local accountState = options.accountState or {}
  local buildContacts = options.buildContacts
  local onSend = options.onSend
  local setDraft = options.setDraft
  local acknowledgeThrough = options.acknowledgeThrough
  local refreshWindow = options.refreshWindow
  local openConversation = options.openConversation

  local function submit(meta, text)
    local contact = findContact(buildContacts(), meta.conversationKey)
    if contact == nil then
      return false
    end

    local accepted = onSend(buildPayload(contact, text))
    if accepted == false then
      return false
    end

    -- Only the answered whisper: a newer one from someone else still shows.
    acknowledgeThrough(meta.sentAt)
    return true
  end

  local function saveDraft(meta, text)
    setDraft(meta.conversationKey, text)
  end

  local function dismissThrough(meta)
    acknowledgeThrough(meta.sentAt)
    refreshWindow()
  end

  local function open(meta, text)
    if Guards.IsRefused(runtime) then
      return false
    end
    if Guards.IsNonEmptyString(text) then
      setDraft(meta.conversationKey, text)
    end
    openConversation(meta.conversationKey)
    return true
  end

  local quickReply = {
    isEnabled = function()
      local settings = accountState.settings
      return type(settings) == "table" and settings.widgetPreviewReply == true
    end,
    getLockReasonText = function()
      local reason = SendHandler.LockReason(runtime)
      return reason and Localization.Text(reason) or nil
    end,
    onSubmit = submit,
    onSaveDraft = saveDraft,
    onDismissThrough = dismissThrough,
    onOpen = open,
    onRefresh = function()
      refreshWindow()
    end,
  }

  return {
    submit = submit,
    saveDraft = saveDraft,
    dismissThrough = dismissThrough,
    open = open,
    quickReply = quickReply,
  }
end

ns.BootstrapWindowRuntimePreviewReplyRuntime = PreviewReplyRuntime

return PreviewReplyRuntime
