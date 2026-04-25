local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactEnricher = ns.ContactEnricher or require("WhisperMessenger.Model.ContactEnricher")
local WhisperGateway = ns.WhisperGateway or require("WhisperMessenger.Transport.WhisperGateway")
local BadgeFilter = ns.ToggleIconBadgeFilter or require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")
local ContactsTabFilter = ns.ContactsTabFilter or require("WhisperMessenger.UI.ContactsList.ContactsTabFilter")

local STATUS_REFRESH_INTERVAL = 30
local AVAILABILITY_THROTTLE_SECONDS = 10
local AVAILABILITY_REFRESH_DEBOUNCE = 0.15

local WindowCoordinator = {}

function WindowCoordinator.Create(options)
  options = options or {}

  local runtime = options.runtime or {}
  local buildContacts = options.buildContacts or function()
    return {}
  end
  local getWindow = options.getWindow or function()
    return nil
  end
  local getIcon = options.getIcon or function()
    return nil
  end
  local buildMessagePreview = options.buildMessagePreview or function()
    return nil
  end
  local trace = options.trace or function(...)
    local _ = ...
  end
  local isMythicRestricted = options.isMythicRestricted or function()
    return false
  end
  local presenceCache = options.presenceCache
  local requestAvailability = options.requestAvailability or WhisperGateway.RequestAvailability
  local cTimer = options.cTimer or _G.C_Timer

  local statusTicker = nil

  local coordinator = {}

  function coordinator.isWindowVisible()
    local window = getWindow()
    if window == nil or window.frame == nil then
      return false
    end

    if window.frame.IsShown then
      return window.frame:IsShown()
    end

    return window.frame.shown == true
  end

  local function nowSeconds()
    if type(runtime.now) == "function" then
      return runtime.now() or 0
    end
    return 0
  end

  local function startStatusTicker()
    if statusTicker or cTimer == nil or type(cTimer.NewTicker) ~= "function" then
      return
    end
    statusTicker = cTimer.NewTicker(STATUS_REFRESH_INTERVAL, function()
      if coordinator.isWindowVisible() then
        coordinator.refreshContacts()
      end
    end)
  end

  local function stopStatusTicker()
    if statusTicker == nil then
      return
    end
    if type(statusTicker.Cancel) == "function" then
      statusTicker:Cancel()
    end
    statusTicker = nil
  end

  function coordinator.setWindowVisible(nextVisible)
    local window = getWindow()
    if window == nil or window.frame == nil then
      return
    end

    trace("set visible=" .. tostring(nextVisible))
    if nextVisible then
      if presenceCache and presenceCache.Rebuild then
        trace("PresenceCache: rebuild on window open")
        presenceCache.Rebuild()
      end
      window.frame:Show()
      -- Re-render after Show so scroll frame dimensions are settled,
      -- allowing snapToEnd to scroll to the latest message.
      coordinator.refreshWindow()
      startStatusTicker()
      return
    end

    stopStatusTicker()
    window.frame:Hide()
  end

  function coordinator.buildSelectionState(contacts)
    return ContactEnricher.BuildWindowSelectionState(runtime, contacts, buildContacts)
  end

  function coordinator.refreshContacts()
    local freshContacts = buildContacts()

    if not isMythicRestricted() then
      runtime.availabilityRequestedAt = runtime.availabilityRequestedAt or {}
      local now = nowSeconds()
      for _, item in ipairs(freshContacts) do
        if
          item.channel == "WOW"
          and item.guid
          and ContactEnricher.ShouldRequestAvailability(runtime.availabilityByGUID[item.guid])
        then
          local lastAt = runtime.availabilityRequestedAt[item.guid] or 0
          if now - lastAt >= AVAILABILITY_THROTTLE_SECONDS then
            runtime.availabilityRequestedAt[item.guid] = now
            requestAvailability(runtime.chatApi, item.guid)
          end
        end
      end
    end

    local nextState = coordinator.buildSelectionState(freshContacts)
    -- Guard against a stale `activeConversationKey` bleeding into the pane
    -- when it doesn't belong to the current tab. Per-tab memory clears the
    -- pane at the moment of swap, but the persistent key isn't reset — so a
    -- later refresh (incoming whisper, availability tick) would re-surface
    -- the off-tab conversation. Match the selection's channel against the
    -- active tab and drop it on mismatch.
    do
      local window = getWindow()
      local tabMode = window and type(window.getTabMode) == "function" and window.getTabMode() or nil
      if tabMode and nextState and nextState.selectedContact then
        local isGroupItem = ContactsTabFilter.IsGroupChannel(nextState.selectedContact.channel)
        local expectedMode = isGroupItem and "groups" or "whispers"
        if expectedMode ~= tabMode then
          nextState = { contacts = nextState.contacts }
        end
      end
    end
    local icon = getIcon()
    if icon and icon.setUnreadCount then
      icon.setUnreadCount(BadgeFilter.SumWhisperUnread(freshContacts))
    end
    if icon and icon.setIncomingPreview then
      -- Suppress the widget-anchored preview only when the Whispers tab is
      -- actually showing — the full conversation is already on screen and
      -- the popup would be redundant. On the Groups tab the whisper isn't
      -- visible in the pane, so the popup is still the user's only surface.
      local window = getWindow()
      local tabMode = window and type(window.getTabMode) == "function" and window.getTabMode() or "whispers"
      local whispersVisibleInPane = coordinator.isWindowVisible() and tabMode == "whispers"
      local preview = not whispersVisibleInPane and buildMessagePreview(freshContacts) or nil
      icon.setIncomingPreview(
        preview and preview.senderName or nil,
        preview and preview.messageText or nil,
        preview and preview.classTag or nil
      )
    end

    return nextState
  end

  function coordinator.refreshWindow()
    local nextState = coordinator.refreshContacts()
    local window = getWindow()

    if coordinator.isWindowVisible() and window and window.refreshSelection then
      window.refreshSelection(nextState)
    end

    return nextState
  end

  local refreshScheduled = false

  function coordinator.scheduleAvailabilityRefresh(_guid)
    if refreshScheduled or not coordinator.isWindowVisible() then
      return
    end
    refreshScheduled = true
    if cTimer and type(cTimer.After) == "function" then
      cTimer.After(AVAILABILITY_REFRESH_DEBOUNCE, function()
        refreshScheduled = false
        if coordinator.isWindowVisible() then
          coordinator.refreshWindow()
        end
      end)
    else
      refreshScheduled = false
      coordinator.refreshWindow()
    end
  end

  function coordinator.findLatestUnreadKey()
    local freshContacts = buildContacts()

    for _, item in ipairs(freshContacts) do
      if (item.unreadCount or 0) > 0 then
        return item.conversationKey
      end
    end

    return nil
  end

  return coordinator
end

ns.BootstrapWindowCoordinator = WindowCoordinator
return WindowCoordinator
