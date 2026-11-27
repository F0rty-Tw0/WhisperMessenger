local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PerfCounters = ns.PerfCounters or require("WhisperMessenger.Util.PerfCounters")

-- Coalesced window refreshes. Busy chats deliver several lines a second;
-- each line records its key and one timer refreshes the window once for all.
local IncomingRefresh = {}

IncomingRefresh.DELAY = 0.2

-- Returns schedule(key): records key (when not nil) and arms one timer that
-- calls onFlush(keys) with every key recorded since the last flush. Records
-- nothing while the window is hidden; the next open refreshes in full.
function IncomingRefresh.Debounce(cTimer, delay, isWindowVisible, onFlush)
  local pending = {}
  local armed = false

  local function flush()
    armed = false
    local keys = pending
    pending = {}
    if isWindowVisible() then
      onFlush(keys)
    end
  end

  return function(key)
    if not isWindowVisible() then
      return
    end
    if key ~= nil then
      pending[key] = true
    end
    if armed then
      return
    end
    armed = true
    if cTimer and type(cTimer.After) == "function" then
      cTimer.After(delay, flush)
    else
      flush()
    end
  end
end

-- A non-selected focus key makes the coordinator refresh contacts only, so
-- the open conversation wins whenever it is among the changed keys.
local function pickFocusKey(dirtyKeys, getSelectedKey)
  local selectedKey = getSelectedKey()
  if selectedKey ~= nil and dirtyKeys[selectedKey] then
    return selectedKey
  end
  return (next(dirtyKeys))
end

-- Whispers: every refresh asked for in one frame runs once on the next frame
-- (zero-delay timer), never later. Unlike Debounce it also runs while the
-- window is hidden, since that refresh keeps the icon badges current. It
-- rebuilds only the contacts of the keys asked for: a contact snapshot never
-- reads messages, so expiring messages of other chats changes no card, and
-- chats the retention sweep removes are pruned from the cache. Without a
-- timer API each request refreshes at once, in full, still inside the
-- caller's event handler.
-- schedule(key, line): line is the chat line that asked, kept for the guard.
-- options: cTimer, refreshWindow(focusKey, dirtyKeys), getSelectedKey, and
-- optional guard(lines, run), which runs the deferred refresh for those lines
-- (the whisper failsafe, since the event handler has returned by then).
function IncomingRefresh.NextFrame(options)
  local cTimer = options.cTimer
  local refreshWindow = options.refreshWindow
  local getSelectedKey = options.getSelectedKey
  local guard = options.guard
  local pending = {}
  local pendingLines = {}
  local armed = false

  local function flush()
    armed = false
    local keys, lines = pending, pendingLines
    pending, pendingLines = {}, {}
    PerfCounters.Increment("refreshes")
    local focusKey = pickFocusKey(keys, getSelectedKey)
    if guard == nil then
      refreshWindow(focusKey, keys)
      return
    end
    guard(lines, function()
      refreshWindow(focusKey, keys)
    end)
  end

  return function(key, line)
    if not (cTimer and type(cTimer.After) == "function") then
      PerfCounters.Increment("refreshes")
      refreshWindow(key)
      return
    end
    pending[key] = true
    if line ~= nil then
      pendingLines[#pendingLines + 1] = line
    end
    if armed then
      return
    end
    armed = true
    cTimer.After(0, flush)
  end
end

-- options: cTimer, delay, isWindowVisible, refreshWindow(focusKey, dirtyKeys),
-- getSelectedKey. A line without a key forces a full rebuild.
function IncomingRefresh.Create(options)
  local refreshWindow = options.refreshWindow
  local getSelectedKey = options.getSelectedKey
  local fullRefresh = false

  local schedule = IncomingRefresh.Debounce(options.cTimer, options.delay or IncomingRefresh.DELAY, options.isWindowVisible, function(dirtyKeys)
    PerfCounters.Increment("refreshes")
    if fullRefresh then
      fullRefresh = false
      refreshWindow(nil, nil)
      return
    end
    refreshWindow(pickFocusKey(dirtyKeys, getSelectedKey), dirtyKeys)
  end)

  return {
    schedule = function(key)
      if key == nil then
        fullRefresh = true
      end
      schedule(key)
    end,
  }
end

ns.BootstrapWindowCoordinatorIncomingRefresh = IncomingRefresh
return IncomingRefresh
