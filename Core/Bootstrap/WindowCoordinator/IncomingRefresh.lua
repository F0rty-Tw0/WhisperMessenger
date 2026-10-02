local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

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

-- options: cTimer, delay, isWindowVisible, refreshWindow(focusKey, dirtyKeys),
-- getSelectedKey. A line without a key forces a full rebuild.
function IncomingRefresh.Create(options)
  local refreshWindow = options.refreshWindow
  local getSelectedKey = options.getSelectedKey
  local fullRefresh = false

  local schedule = IncomingRefresh.Debounce(options.cTimer, options.delay or IncomingRefresh.DELAY, options.isWindowVisible, function(dirtyKeys)
    if fullRefresh then
      fullRefresh = false
      refreshWindow(nil, nil)
      return
    end
    -- A non-selected focus key makes the coordinator refresh contacts only.
    local selectedKey = getSelectedKey()
    local focusKey = selectedKey ~= nil and dirtyKeys[selectedKey] and selectedKey or next(dirtyKeys)
    refreshWindow(focusKey, dirtyKeys)
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
