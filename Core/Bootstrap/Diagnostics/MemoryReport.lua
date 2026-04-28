local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local MemoryReport = {}

local function countRegions(frame)
  local count = 0
  if frame.GetRegions then
    local regions = { frame:GetRegions() }
    count = count + #regions
  end
  if frame.GetChildren then
    local children = { frame:GetChildren() }
    count = count + #children
  end
  return count
end

function MemoryReport.Create(options)
  options = options or {}

  local runtime = options.runtime or {}
  local trace = options.trace or function(...)
    local _ = ...
  end
  local getWindow = options.getWindow or function()
    return nil
  end
  local isWindowVisible = options.isWindowVisible or function()
    return false
  end
  local updateAddOnMemoryUsage = options.updateAddOnMemoryUsage
  local getAddOnMemoryUsage = options.getAddOnMemoryUsage
  local collectgarbageFn = options.collectgarbage
  local resolvedAddonName = options.addonName or addonName

  local prevSnapshot = nil

  local reporter = {}

  function reporter.run()
    local fmt = string.format
    local pairsFn = pairs

    trace("=== WhisperMessenger Memory Report ===")

    local preGcKB = 0
    if type(updateAddOnMemoryUsage) == "function" then
      updateAddOnMemoryUsage()
      if type(getAddOnMemoryUsage) == "function" then
        preGcKB = getAddOnMemoryUsage(resolvedAddonName) or 0
      end
    end

    local postGcKB = 0
    if type(collectgarbageFn) == "function" then
      collectgarbageFn("collect")
    end
    if type(updateAddOnMemoryUsage) == "function" then
      updateAddOnMemoryUsage()
      if type(getAddOnMemoryUsage) == "function" then
        postGcKB = getAddOnMemoryUsage(resolvedAddonName) or 0
      end
    end

    local garbageKB = preGcKB - postGcKB
    trace("  WM pre-GC:  " .. fmt("%.1f", preGcKB) .. " KB  (game menu sees this)")
    trace("  WM post-GC: " .. fmt("%.1f", postGcKB) .. " KB  (actual footprint)")
    if garbageKB > 0 then
      trace("  Garbage:    " .. fmt("%.1f", garbageKB) .. " KB  (transient, reclaimable)")
    end
    if type(collectgarbageFn) == "function" then
      trace("  Lua total:  " .. fmt("%.0f", collectgarbageFn("count")) .. " KB")
    end
    local wmKB = postGcKB

    local conversations = runtime.store and runtime.store.conversations or {}
    local convCount = 0
    local totalMessages = 0
    local totalUnread = 0
    local largestConv = 0
    local largestConvKey = "none"
    for key, conversation in pairsFn(conversations) do
      convCount = convCount + 1
      local msgCount = #(conversation.messages or {})
      totalMessages = totalMessages + msgCount
      totalUnread = totalUnread + (conversation.unreadCount or 0)
      if msgCount > largestConv then
        largestConv = msgCount
        largestConvKey = key
      end
    end
    trace("  Conversations: " .. convCount .. "  Messages: " .. totalMessages .. "  Unread: " .. totalUnread)
    if largestConv > 0 then
      trace("  Largest: " .. largestConv .. " msgs (" .. largestConvKey .. ")")
    end

    local availabilityByGUID = runtime.availabilityByGUID or {}
    local availCount = 0
    for _ in pairsFn(availabilityByGUID) do
      availCount = availCount + 1
    end
    local pendingOutgoing = runtime.pendingOutgoing or {}
    local pendingCount = 0
    for _ in pairsFn(pendingOutgoing) do
      pendingCount = pendingCount + 1
    end
    trace("  Avail cache: " .. availCount .. "  Pending: " .. pendingCount)

    local window = getWindow()
    trace("  Window: " .. (window and (isWindowVisible() and "visible" or "hidden") or "not created"))

    local snapshot = { wmKB = wmKB, pools = {} }

    if window and window.conversation and window.conversation.transcript then
      local contentFrame = window.conversation.transcript.content
      if contentFrame and contentFrame._activeFrames then
        local activeCount = #contentFrame._activeFrames
        local freeCount = contentFrame._freeFrames and #contentFrame._freeFrames or 0
        local totalFrames = activeCount + freeCount
        local totalRegions = 0

        for _, frame in ipairs(contentFrame._activeFrames) do
          totalRegions = totalRegions + countRegions(frame)
        end
        if contentFrame._freeFrames then
          for _, frame in ipairs(contentFrame._freeFrames) do
            totalRegions = totalRegions + countRegions(frame)
          end
        end

        snapshot.pools = { active = activeCount, free = freeCount, regions = totalRegions }
        trace("  --- Frame Pool ---")
        trace("  Frames: " .. activeCount .. " active / " .. freeCount .. " free / " .. totalFrames .. " total  |  regions: " .. totalRegions)
      end
    end

    if prevSnapshot then
      trace("  --- Delta from last /wmsg mem ---")
      local deltaKB = wmKB - prevSnapshot.wmKB
      trace("  WM memory: " .. (deltaKB >= 0 and "+" or "") .. fmt("%.1f", deltaKB) .. " KB")
      if snapshot.pools.active and prevSnapshot.pools.active then
        local frameDelta = (snapshot.pools.active + snapshot.pools.free) - (prevSnapshot.pools.active + prevSnapshot.pools.free)
        local regionDelta = snapshot.pools.regions - prevSnapshot.pools.regions
        if frameDelta ~= 0 or regionDelta ~= 0 then
          trace("  Frames: " .. (frameDelta >= 0 and "+" or "") .. frameDelta .. "  regions: " .. (regionDelta >= 0 and "+" or "") .. regionDelta)
        end
      end
    end

    prevSnapshot = snapshot
    trace("=== End Memory Report ===")
  end

  return reporter
end

ns.BootstrapDiagnosticsMemoryReport = MemoryReport

return MemoryReport
