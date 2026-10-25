local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PanelBadge = ns.PanelBadge or require("WhisperMessenger.UI.Shared.PanelBadge")

-- Keeps the panels other addons register before the window exists (it is
-- built on first open) and hands them to it, in registration order, once it
-- does. After that a registration goes straight to the window.
local PanelRegistry = {}

local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber

-- A contact's unread count as the observer sees it: WoW whispers only.
local function whisperUnread(contact)
  if contact.channel ~= "WOW" or contact.conversationKey == nil then
    return 0
  end
  return tonumber(contact.unreadCount) or 0
end

function PanelRegistry.New()
  local panels = {}
  local order = {}
  local window = nil
  -- The WoW chats with unread whispers at the last observation: key -> count.
  local unread = {}
  local unreadSize = 0
  local hasBaseline = false
  local pending = false

  local function register(key, panel)
    if panels[key] ~= nil then
      return false
    end
    if window ~= nil and not window.registerPanel(key, panel) then
      return false
    end
    panels[key] = panel
    order[#order + 1] = key
    return true
  end

  local function bind(nextWindow)
    window = nextWindow
    for _, key in ipairs(order) do
      window.registerPanel(key, panels[key])
    end
  end

  -- Read the way the panel's tab reads it, so the numbers agree.
  local function readBadge(key)
    return PanelBadge.Read(panels[key].badge)
  end

  -- What the panels add to the icon number.
  local function badgeSum()
    local sum = 0
    for _, key in ipairs(order) do
      sum = sum + readBadge(key)
    end
    return sum
  end

  -- The first panel, in registration order, with something waiting.
  local function firstBadgedKey()
    for _, key in ipairs(order) do
      if readBadge(key) > 0 then
        return key
      end
    end
    return nil
  end

  -- The player marked everything read: tell each panel, in registration
  -- order (one panel's error stops no other), then re-read the tab badges.
  local function markAllRead()
    for _, key in ipairs(order) do
      local callback = panels[key].onMarkAllRead
      if callback ~= nil then
        pcall(callback)
      end
    end
    if window == nil or window.refreshPanelBadge == nil then
      return
    end
    for _, key in ipairs(order) do
      pcall(window.refreshPanelBadge, key)
    end
  end

  -- Compared in place, so an unchanged set allocates nothing.
  local function unreadChanged(contacts)
    local size = 0
    for _, contact in ipairs(contacts) do
      local count = whisperUnread(contact)
      if count > 0 then
        size = size + 1
        if unread[contact.conversationKey] ~= count then
          return true
        end
      end
    end
    return size ~= unreadSize
  end

  local function recordUnread(contacts)
    for key in pairs(unread) do
      unread[key] = nil
    end
    unreadSize = 0
    for _, contact in ipairs(contacts) do
      local count = whisperUnread(contact)
      if count > 0 then
        unread[contact.conversationKey] = count
        unreadSize = unreadSize + 1
      end
    end
  end

  -- Idle again before the calls, so a change made inside one schedules anew.
  -- One panel's error stops no other.
  local function notifyUnread()
    pending = false
    for _, key in ipairs(order) do
      local callback = panels[key].onUnreadChanged
      if callback ~= nil then
        pcall(callback)
      end
    end
  end

  local function hasUnreadListener()
    for _, key in ipairs(order) do
      if panels[key].onUnreadChanged ~= nil then
        return true
      end
    end
    return false
  end

  local function scheduleNotify()
    local timer = _G.C_Timer
    if pending or not (timer and timer.After) or not hasUnreadListener() then
      return
    end
    pending = true
    timer.After(0, notifyUnread)
  end

  -- Runs on every icon refresh. The first call only records a baseline; after
  -- that a changed set of unread WoW chats tells the panels on the next frame,
  -- once however many changes come before it.
  local function observeUnread(contacts)
    local changed = unreadChanged(contacts)
    if changed then
      recordUnread(contacts)
      if hasBaseline then
        scheduleNotify()
      end
    end
    hasBaseline = true
  end

  return {
    register = register,
    markAllRead = markAllRead,
    observeUnread = observeUnread,
    badgeSum = badgeSum,
    firstBadgedKey = firstBadgedKey,
    get = function(key)
      return panels[key]
    end,
    bind = bind,
  }
end

ns.BootstrapWindowRuntimePanelRegistry = PanelRegistry
return PanelRegistry
