local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BadgeFilter = ns.ToggleIconBadgeFilter or require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")
local AlertPolicy = ns.AlertPolicy or require("WhisperMessenger.Model.AlertPolicy")

local WidgetPreview = {}

function WidgetPreview.Create(options)
  options = options or {}

  local accountState = options.accountState or {}
  local runtimeStore = options.runtimeStore or {}
  local badgeFilter = options.badgeFilter or BadgeFilter

  -- includeQuiet: also count muted chats and message requests (used to
  -- acknowledge, so unmuting or accepting later never pops a message that
  -- was already on screen).
  local function findLatestIncomingPreview(contacts, includeQuiet)
    local storeConversations = runtimeStore.conversations or {}
    local savedConversations = accountState.conversations or {}
    local latest = nil

    for _, item in ipairs(contacts or {}) do
      local conversation = savedConversations[item.conversationKey] or storeConversations[item.conversationKey]
      -- Group chats never produce a widget preview — per user requirement,
      -- the popup is reserved for whispers. Muted whispers and message requests
      -- never pop it either.
      if not badgeFilter.IsGroupChannel(item.channel) and (includeQuiet or AlertPolicy.ShouldAlert(conversation, accountState.settings)) then
        local sentAt = conversation and tonumber(conversation.lastIncomingAt) or nil
        local messageText = conversation and conversation.lastIncomingPreview or nil
        if sentAt and type(messageText) == "string" and messageText ~= "" then
          local senderName = conversation.lastIncomingSender or item.displayName or conversation.displayName
          if type(senderName) == "string" and senderName ~= "" then
            if latest == nil or sentAt > latest.sentAt then
              latest = {
                sentAt = sentAt,
                senderName = senderName,
                messageText = messageText,
                classTag = item.classTag or conversation.classTag,
              }
            end
          end
        end
      end
    end

    return latest
  end

  local function buildLatestIncomingPreview(contacts)
    if accountState.settings and accountState.settings.showWidgetMessagePreview == false then
      return nil
    end

    local acknowledgedAt = tonumber(accountState.widgetPreviewAcknowledgedAt)
    local latest = findLatestIncomingPreview(contacts)
    if latest and acknowledgedAt and latest.sentAt <= acknowledgedAt then
      return nil
    end

    return latest
  end

  local function acknowledgeLatestWidgetPreview(contacts)
    local latest = findLatestIncomingPreview(contacts, true)
    if latest == nil then
      return
    end

    local acknowledgedAt = tonumber(accountState.widgetPreviewAcknowledgedAt) or 0
    if latest.sentAt > acknowledgedAt then
      accountState.widgetPreviewAcknowledgedAt = latest.sentAt
    end
  end

  return {
    findLatestIncomingPreview = findLatestIncomingPreview,
    buildLatestIncomingPreview = buildLatestIncomingPreview,
    acknowledgeLatestWidgetPreview = acknowledgeLatestWidgetPreview,
  }
end

ns.BootstrapWindowRuntimeWidgetPreview = WidgetPreview

return WidgetPreview
