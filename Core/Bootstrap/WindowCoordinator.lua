local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactEnricher = ns.ContactEnricher or require("WhisperMessenger.Model.ContactEnricher")
local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
local WhisperGateway = ns.WhisperGateway or require("WhisperMessenger.Transport.WhisperGateway")

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
  local trace = options.trace or function(...)
    local _ = ...
  end
  local isMythicRestricted = options.isMythicRestricted or function()
    return false
  end
  local presenceCache = options.presenceCache

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
      return
    end

    window.frame:Hide()
  end

  function coordinator.buildSelectionState(contacts)
    return ContactEnricher.BuildWindowSelectionState(runtime, contacts, buildContacts)
  end

  function coordinator.refreshContacts()
    local freshContacts = buildContacts()

    if not isMythicRestricted() then
      for _, item in ipairs(freshContacts) do
        if
          item.channel == "WOW"
          and item.guid
          and ContactEnricher.ShouldRequestAvailability(runtime.availabilityByGUID[item.guid])
        then
          WhisperGateway.RequestAvailability(runtime.chatApi, item.guid)
        end
      end
    end

    local nextState = coordinator.buildSelectionState(freshContacts)
    local icon = getIcon()
    if icon and icon.setUnreadCount then
      icon.setUnreadCount(TableUtils.sumBy(freshContacts, "unreadCount"))
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
