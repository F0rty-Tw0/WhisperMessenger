local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FramePool = {}

function FramePool.initPool(contentFrame)
  if not contentFrame._freeFrames then
    contentFrame._freeFrames = {}
    contentFrame._activeFrames = {}
    -- Migrate legacy _bubblePool if present
    if contentFrame._bubblePool then
      for _, f in ipairs(contentFrame._bubblePool) do
        if f.Hide then
          f:Hide()
        end
        table.insert(contentFrame._freeFrames, f)
      end
      contentFrame._bubblePool = nil
    end
  end
end

function FramePool.acquireFrame(realFactory, contentFrame, frameType, parent)
  local free = contentFrame._freeFrames
  local frame = table.remove(free)
  if frame then
    if frame.Show then
      frame:Show()
    end
    if frame.ClearAllPoints then
      frame:ClearAllPoints()
    end
  else
    frame = realFactory.CreateFrame(frameType, nil, parent)
  end
  table.insert(contentFrame._activeFrames, frame)
  return frame
end

function FramePool.hideAllRegions(frame)
  if frame.GetRegions then
    local regions = { frame:GetRegions() }
    for _, r in ipairs(regions) do
      if r.Hide then
        r:Hide()
      end
    end
  end
  if frame.GetChildren then
    local children = { frame:GetChildren() }
    for _, c in ipairs(children) do
      if c.Hide then
        c:Hide()
      end
    end
  end
end

function FramePool.releaseAll(contentFrame)
  local active = contentFrame._activeFrames
  local free = contentFrame._freeFrames
  for i = #active, 1, -1 do
    local f = active[i]
    FramePool.hideAllRegions(f)
    if f.Hide then
      f:Hide()
    end
    if f.ClearAllPoints then
      f:ClearAllPoints()
    end
    table.insert(free, f)
    active[i] = nil
  end
end

ns.ChatBubbleFramePool = FramePool
return FramePool
