local FakeUI = require("tests.helpers.fake_ui")
local FramePool = require("WhisperMessenger.UI.ChatBubble.FramePool")

return function()
  local factory = FakeUI.NewFactory()

  -- test_init_pool_creates_free_and_active_tables
  do
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    FramePool.initPool(contentFrame)
    assert(type(contentFrame._freeFrames) == "table", "expected _freeFrames to be a table")
    assert(type(contentFrame._activeFrames) == "table", "expected _activeFrames to be a table")
  end

  -- test_acquire_frame_creates_new_when_pool_empty
  do
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    FramePool.initPool(contentFrame)
    local realFactory = FakeUI.NewFactory()
    local frame = FramePool.acquireFrame(realFactory, contentFrame, "Frame", contentFrame)
    assert(frame ~= nil, "expected acquireFrame to return a frame when pool is empty")
    assert(#contentFrame._activeFrames == 1, "expected one active frame after acquire")
  end

  -- test_acquire_frame_reuses_from_free_pool
  do
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    FramePool.initPool(contentFrame)
    local realFactory = FakeUI.NewFactory()
    local existingFrame = realFactory.CreateFrame("Frame", nil, contentFrame)
    existingFrame:Hide()
    table.insert(contentFrame._freeFrames, existingFrame)

    local createCount = 0
    local trackingFactory = {
      CreateFrame = function(frameType, name, parent)
        createCount = createCount + 1
        return realFactory.CreateFrame(frameType, name, parent)
      end,
    }

    local frame = FramePool.acquireFrame(trackingFactory, contentFrame, "Frame", contentFrame)
    assert(frame == existingFrame, "expected acquireFrame to reuse the frame from free pool")
    assert(createCount == 0, "expected no new CreateFrame calls when reusing from pool")
    assert(frame.shown == true, "expected reused frame to be shown")
  end

  -- test_release_all_moves_active_to_free
  do
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    FramePool.initPool(contentFrame)
    local realFactory = FakeUI.NewFactory()

    FramePool.acquireFrame(realFactory, contentFrame, "Frame", contentFrame)
    FramePool.acquireFrame(realFactory, contentFrame, "Frame", contentFrame)
    assert(#contentFrame._activeFrames == 2, "expected 2 active frames before releaseAll")

    FramePool.releaseAll(contentFrame)
    assert(#contentFrame._activeFrames == 0, "expected _activeFrames to be empty after releaseAll")
    assert(#contentFrame._freeFrames == 2, "expected 2 frames in free pool after releaseAll")
  end

  -- test_hide_all_regions_hides_children_and_regions
  do
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    local region1 = contentFrame:CreateFontString(nil, "OVERLAY")
    region1:Show()
    local region2 = contentFrame:CreateTexture(nil, "ARTWORK")
    region2:Show()

    FramePool.hideAllRegions(contentFrame)
    assert(region1.shown == false, "expected FontString region to be hidden")
    assert(region2.shown == false, "expected Texture region to be hidden")
  end

  -- test_release_all_clears_interactive_scripts
  -- Regression: bubble frames wire OnEnter/OnLeave that show the hover copy
  -- icon via a closure-captured button. When the pool recycles that frame
  -- into a sender label or class-icon slot, the stale script still fires —
  -- so hovering the player's name or class icon re-shows the orphaned copy
  -- icon. releaseAll must null out interactive handlers before pushing the
  -- frame back to the free list.
  do
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    FramePool.initPool(contentFrame)
    local realFactory = FakeUI.NewFactory()

    local frame = FramePool.acquireFrame(realFactory, contentFrame, "Frame", contentFrame)
    local enterFired = false
    local leaveFired = false
    frame:SetScript("OnEnter", function()
      enterFired = true
    end)
    frame:SetScript("OnLeave", function()
      leaveFired = true
    end)
    frame:SetScript("OnMouseDown", function() end)
    frame:SetScript("OnMouseUp", function() end)

    FramePool.releaseAll(contentFrame)

    assert(frame:GetScript("OnEnter") == nil, "expected OnEnter cleared after releaseAll")
    assert(frame:GetScript("OnLeave") == nil, "expected OnLeave cleared after releaseAll")
    assert(frame:GetScript("OnMouseDown") == nil, "expected OnMouseDown cleared after releaseAll")
    assert(frame:GetScript("OnMouseUp") == nil, "expected OnMouseUp cleared after releaseAll")
    assert(enterFired == false and leaveFired == false, "scripts must not fire as a side-effect of release")
  end

  -- test_release_all_does_not_touch_onclick
  -- WoW raises a warning when SetScript("OnClick", ...) is called on a
  -- non-Button frame. Pooled frames are all "Frame" type, so releaseAll must
  -- not poke OnClick at all — even to clear it.
  do
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    FramePool.initPool(contentFrame)
    local realFactory = FakeUI.NewFactory()

    local frame = FramePool.acquireFrame(realFactory, contentFrame, "Frame", contentFrame)
    local touched = false
    local realSetScript = frame.SetScript
    frame.SetScript = function(self, eventName, handler)
      if eventName == "OnClick" then
        touched = true
      end
      return realSetScript(self, eventName, handler)
    end

    FramePool.releaseAll(contentFrame)

    assert(touched == false, "releaseAll must not call SetScript('OnClick', ...) on pooled Frames")
  end
end
