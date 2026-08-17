local ScrollView = require("WhisperMessenger.UI.ScrollView")
local Metrics = require("WhisperMessenger.UI.ScrollView.Metrics")
local FakeUI = require("tests.helpers.fake_ui")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane.ConversationPane")

local function withCapturedTimer(callback)
  local savedTimer = _G.C_Timer
  local scheduled = {}

  _G.C_Timer = {
    After = function(delay, timerCallback)
      table.insert(scheduled, {
        callback = timerCallback,
        delay = delay,
      })
    end,
  }

  local ok, err = pcall(function()
    callback(function()
      local timer = table.remove(scheduled, 1)
      if timer == nil then
        return nil, nil
      end
      return timer.callback, timer.delay
    end)
  end)

  _G.C_Timer = savedTimer
  if not ok then
    error(err, 0)
  end
end

return function()
  local factory = FakeUI.NewFactory()

  -- test_get_range_falls_back_when_wow_returns_zero

  do
    local view = ScrollView.Create(factory, factory.CreateFrame("Frame", nil, nil), {
      width = 300,
      height = 200,
    })

    -- Content is taller than viewport
    view.content:SetSize(300, 600)

    -- Simulate stale WoW layout: GetVerticalScrollRange returns 0
    view.scrollFrame.GetVerticalScrollRange = function()
      return 0
    end

    local range = Metrics.GetRange(view)
    assert(range == 400, "GetRange should fall back to manual calc (600 - 200 = 400), got: " .. tostring(range))
  end

  -- test_refresh_metrics_snap_to_end_with_stale_layout

  do
    local view = ScrollView.Create(factory, factory.CreateFrame("Frame", nil, nil), {
      width = 300,
      height = 200,
    })

    -- Simulate stale WoW layout: GetVerticalScrollRange returns 0
    -- but SetVerticalScroll still accepts any value (WoW behavior)
    view.scrollFrame.GetVerticalScrollRange = function()
      return 0
    end
    view.scrollFrame.SetVerticalScroll = function(self, v)
      self.verticalScroll = v
    end

    Metrics.RefreshMetrics(view, 600, true)

    local offset = view.scrollFrame.verticalScroll or 0
    assert(offset > 0, "snapToEnd should scroll to bottom even with stale layout, got offset: " .. tostring(offset))
    assert(offset == 400, "snapToEnd offset should be 400 (600 - 200), got: " .. tostring(offset))
  end

  -- test_refresh_metrics_snap_to_end_normal_case

  do
    local view = ScrollView.Create(factory, factory.CreateFrame("Frame", nil, nil), {
      width = 300,
      height = 200,
    })

    Metrics.RefreshMetrics(view, 600, true)

    local offset = view.scrollFrame:GetVerticalScroll()
    assert(offset == 400, "snapToEnd offset should be 400 (600 - 200), got: " .. tostring(offset))
  end

  -- test_snap_to_end_falls_back_to_captured_viewport_when_live_height_is_zero
  -- Regression: on incoming whispers, WoW sometimes reports scrollFrame
  -- height as 0 while it is being re-laid out. Without the fallback,
  -- Metrics.GetRange returns 0 and snap-to-end collapses to offset 0 (top)
  -- instead of landing on the latest message.

  do
    local view = ScrollView.Create(factory, factory.CreateFrame("Frame", nil, nil), {
      width = 300,
      height = 200,
    })

    view.scrollFrame.GetHeight = function()
      return 0
    end

    Metrics.RefreshMetrics(view, 600, true)

    local offset = view.scrollFrame:GetVerticalScroll()
    assert(offset == 400, "snapToEnd should use captured viewport (200) when live height is 0, expected offset 400, got: " .. tostring(offset))
  end

  -- test_tiny_overflow_does_not_show_scrollbar
  -- Regression: live WoW can report a few pixels of harmless overflow after
  -- bubble layout settles. That should not expose a scrollbar that only moves
  -- 1-5 px in short conversations.

  do
    local view = ScrollView.Create(factory, factory.CreateFrame("Frame", nil, nil), {
      width = 300,
      height = 200,
    })

    Metrics.RefreshMetrics(view, 204, true)

    assert(view.scrollBar.shown == false, "tiny overflow should not show scrollbar")
    assert(view.scrollFrame:GetVerticalScroll() == 0, "tiny overflow should not leave a scroll offset")
  end

  -- test_snap_to_end_retries_after_native_range_catches_up
  -- Regression: WoW can clamp SetVerticalScroll against a stale native
  -- GetVerticalScrollRange even after our own content math knows the correct
  -- bottom. A deferred retry is required once the native range catches up.

  do
    withCapturedTimer(function(getScheduled)
      local view = ScrollView.Create(factory, factory.CreateFrame("Frame", nil, nil), {
        width = 300,
        height = 200,
      })

      local nativeRangeSettled = false
      view.scrollFrame.GetVerticalScrollRange = function()
        if nativeRangeSettled then
          return 400
        end
        return 200
      end

      Metrics.RefreshMetrics(view, 600, true)

      local scheduled, scheduledDelay = getScheduled()
      assert(view.scrollFrame:GetVerticalScroll() == 200, "first snap should demonstrate stale native clamp")
      assert(type(scheduled) == "function", "snap-to-end should schedule a retry when native range clamps early")
      assert(scheduledDelay == 0, "snap-to-end retry should run on the next frame")

      nativeRangeSettled = true
      scheduled()

      assert(view.scrollFrame:GetVerticalScroll() == 400, "deferred snap should land on latest message after native range settles")
    end)
  end

  -- test_snap_to_end_retries_until_native_range_settles_on_third_frame
  -- Regression: WoW can keep the native range stale through two deferred
  -- layout frames, then settle on the third.

  do
    withCapturedTimer(function(getScheduled)
      local view = ScrollView.Create(factory, factory.CreateFrame("Frame", nil, nil), {
        width = 300,
        height = 200,
      })

      local layoutFrame = 0
      view.scrollFrame.GetVerticalScrollRange = function()
        if layoutFrame < 3 then
          return 200
        end
        return 400
      end

      Metrics.RefreshMetrics(view, 600, true)

      for frame = 1, 3 do
        layoutFrame = frame
        local scheduled = getScheduled()
        if scheduled then
          scheduled()
        end
      end

      local offset = view.scrollFrame:GetVerticalScroll()
      assert(offset == 400, "snap-to-end should reach 400 after native range settles on the third deferred frame, got: " .. tostring(offset))
    end)
  end

  -- test_newer_snap_to_end_request_survives_older_pending_retry
  -- Regression: a stale callback from an older snap request must not cancel
  -- or consume the pending retry for a newer request.

  do
    withCapturedTimer(function(getScheduled)
      local view = ScrollView.Create(factory, factory.CreateFrame("Frame", nil, nil), {
        width = 300,
        height = 200,
      })

      local nativeRange = 200
      view.scrollFrame.GetVerticalScrollRange = function()
        return nativeRange
      end

      Metrics.RefreshMetrics(view, 600, true)

      nativeRange = 300
      Metrics.RefreshMetrics(view, 800, true)

      local olderScheduled = getScheduled()
      if olderScheduled then
        olderScheduled()
      end

      nativeRange = 600
      local scheduled = getScheduled()
      while scheduled do
        scheduled()
        scheduled = getScheduled()
      end

      local offset = view.scrollFrame:GetVerticalScroll()
      assert(offset == 600, "newer snap-to-end should reach 600 after native range settles, got: " .. tostring(offset))
    end)
  end

  -- test_snap_to_end_retry_does_not_override_user_scroll

  do
    withCapturedTimer(function(getScheduled)
      local view = ScrollView.Create(factory, factory.CreateFrame("Frame", nil, nil), {
        width = 300,
        height = 200,
      })

      local nativeRangeSettled = false
      view.scrollFrame.GetVerticalScrollRange = function()
        if nativeRangeSettled then
          return 400
        end
        return 200
      end

      Metrics.RefreshMetrics(view, 600, true)

      local scheduled = getScheduled()
      assert(type(scheduled) == "function", "snap-to-end should schedule a retry before the user scrolls")

      view.scrollFrame.verticalScroll = 100
      nativeRangeSettled = true
      scheduled()

      assert(view.scrollFrame:GetVerticalScroll() == 100, "deferred snap should not override a changed scroll offset")
    end)
  end

  local function makeMessages(count, prefix)
    local messages = {}
    for index = 1, count do
      messages[index] = {
        direction = "in",
        text = prefix .. index,
      }
    end
    return messages
  end

  local function makeConversationPaneView()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(300, 200)
    return {
      header = parent:CreateFontString(nil, "OVERLAY"),
      transcript = ScrollView.Create(factory, parent, {
        width = 300,
        height = 200,
      }),
    }
  end

  -- test_conversation_refresh_preserves_loaded_depth_for_same_selection

  do
    local view = makeConversationPaneView()
    local contact = { conversationKey = "me::WOW::arthas", displayName = "Arthas" }
    local conversation = { messages = makeMessages(30, "message ") }

    ConversationPane.Refresh(view, contact, conversation)
    assert(ConversationPane.LoadMore(view.transcript), "expected load-more to reveal an older page")
    assert(view.transcript._visibleCount == 20, "load-more should reveal two pages")

    ConversationPane.Refresh(view, contact, conversation)
    assert(view.transcript._visibleCount == 20, "same-conversation refresh should retain loaded depth")

    ConversationPane.Refresh(view, contact, conversation, { status = "offline" })
    assert(view.transcript._visibleCount == 20, "availability refresh should retain loaded depth")
  end

  -- test_conversation_refresh_resets_loaded_depth_for_different_selection

  do
    local view = makeConversationPaneView()
    local arthas = { conversationKey = "me::WOW::arthas", displayName = "Arthas" }
    local jaina = { conversationKey = "me::WOW::jaina", displayName = "Jaina" }

    ConversationPane.Refresh(view, arthas, { messages = makeMessages(30, "arthas ") })
    assert(ConversationPane.LoadMore(view.transcript), "expected load-more before switching conversations")
    ConversationPane.Refresh(view, jaina, { messages = makeMessages(30, "jaina ") })

    assert(view.transcript._visibleCount == 10, "different conversation should reset to initial page size")
  end

  -- test_conversation_refresh_clamps_loaded_depth_after_history_shrinks

  do
    local view = makeConversationPaneView()
    local contact = { conversationKey = "me::WOW::arthas", displayName = "Arthas" }

    ConversationPane.Refresh(view, contact, { messages = makeMessages(30, "old ") })
    assert(ConversationPane.LoadMore(view.transcript), "expected load-more before retained history shrinks")
    ConversationPane.Refresh(view, contact, { messages = makeMessages(15, "retained ") })

    assert(view.transcript._visibleCount == 15, "refresh should clamp retained depth to available history")
  end

  print("PASS: test_scroll_snap_to_end")
end
