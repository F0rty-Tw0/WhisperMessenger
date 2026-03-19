local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Queue = {}

function Queue.New()
  return {
    items = {},
    indexByLineID = {},
  }
end

function Queue.Enqueue(queue, item)
  if not item or item.lineID == nil then
    return false
  end

  if queue.indexByLineID[item.lineID] then
    return false
  end

  table.insert(queue.items, item)
  queue.indexByLineID[item.lineID] = true
  return true
end

function Queue.ReplayReady(queue, isLocked, hydrate, reducer)
  if isLocked then
    return 0
  end

  local processed = 0

  while #queue.items > 0 do
    local item = table.remove(queue.items, 1)
    queue.indexByLineID[item.lineID] = nil

    local message = hydrate(item)
    if message ~= nil then
      reducer(message, item)
    end

    processed = processed + 1
  end

  return processed
end

ns.LockdownQueue = Queue

return Queue
