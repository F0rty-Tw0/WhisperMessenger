-- Measures the garbage an animation tick makes. The fake frame builds a table
-- in SetPoint and GetPoint, so a raw KB delta would measure the fake, not the
-- module; Quiet swaps the calls an animation makes for allocation-free ones
-- that count themselves and keep the state the module reads back.
local AnimAlloc = {}

local function counter(counts, name, run)
  counts[name] = 0
  return function(self, ...)
    counts[name] = counts[name] + 1
    if run then
      run(self, ...)
    end
  end
end

-- Stubs the per-tick frame calls on `frame` and counts them by name in `counts`.
function AnimAlloc.Quiet(frame, counts)
  rawset(frame, "SetPoint", counter(counts, "SetPoint"))
  rawset(frame, "ClearAllPoints", counter(counts, "ClearAllPoints"))
  rawset(
    frame,
    "SetSize",
    counter(counts, "SetSize", function(self, width, height)
      self.width, self.height = width, height
    end)
  )
  rawset(
    frame,
    "SetScale",
    counter(counts, "SetScale", function(self, scale)
      self.scale = scale
    end)
  )
  rawset(
    frame,
    "SetAlpha",
    counter(counts, "SetAlpha", function(self, alpha)
      self.alpha = alpha
    end)
  )
  rawset(
    frame,
    "Show",
    counter(counts, "Show", function(self)
      self.shown = true
    end)
  )
  rawset(
    frame,
    "Hide",
    counter(counts, "Hide", function(self)
      self.shown = false
    end)
  )
  rawset(frame, "GetPoint", counter(counts, "GetPoint"))
  return frame
end

-- Zeroes every counter, so a warm-up call does not count.
function AnimAlloc.Reset(counts)
  for name in pairs(counts) do
    counts[name] = 0
  end
end

-- KB the garbage collector did not get to free over n calls of tick().
function AnimAlloc.Measure(tick, n)
  collectgarbage("collect")
  collectgarbage("stop")
  local before = collectgarbage("count")
  for _ = 1, n do
    tick()
  end
  local after = collectgarbage("count")
  collectgarbage("restart")
  return after - before
end

return AnimAlloc
