local Queue = require("WhisperMessenger.Model.LockdownQueue")
local fixture = dofile("tests/fixtures/lockdown.lua")

return function()
  local queue = Queue.New()

  Queue.Enqueue(queue, fixture.first)
  Queue.Enqueue(queue, fixture.second)
  Queue.Enqueue(queue, fixture.first)

  assert(#queue.items == 2)

  local replayed = {}
  local blocked = Queue.ReplayReady(queue, true, function(item)
    return { lineID = item.lineID, text = "hydrated-" .. item.lineID }
  end, function(message)
    table.insert(replayed, message)
  end)

  assert(blocked == 0)
  assert(#queue.items == 2)
  assert(#replayed == 0)

  local processed = Queue.ReplayReady(queue, false, function(item)
    return { lineID = item.lineID, text = "hydrated-" .. item.lineID }
  end, function(message)
    table.insert(replayed, message)
  end)

  assert(processed == 2)
  assert(#queue.items == 0)
  assert(replayed[1].lineID == 42)
  assert(replayed[2].lineID == 43)
end
