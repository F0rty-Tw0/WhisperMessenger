local M = require("WhisperMessenger.UI.ToggleIcon.PreviewMetrics")

local function label(width)
  return {
    SetWidth = function() end,
    GetStringWidth = function()
      return width
    end,
  }
end

local function frame()
  return {
    SetWidth = function(self, w)
      self.w = w
    end,
  }
end

return function()
  -- test_unknown_position_falls_back_to_right
  local right = M.ResolveAnchor("sideways")
  assert(right.selfPoint == "LEFT" and right.target == "RIGHT" and right.x == M.GAP, "unknown position falls back to right")

  -- test_detached_hangs_from_the_holder_top
  local detached = M.ResolveAnchor("detached")
  assert(detached.selfPoint == "TOP" and detached.target == "TOP", "detached card hangs from the holder's top")
  assert(detached.x == 0 and detached.y == 0, "detached card sits exactly on the holder")

  -- test_above_and_top_anchor_on_the_bottom_edge
  assert(M.ResolveAnchor("above").selfPoint == "BOTTOM", "above anchors the preview's bottom edge")
  assert(M.ResolveAnchor("top").y == M.GAP, "top sits one gap above the icon")

  -- test_long_text_caps_at_max_width
  local wide = frame()
  M.ResizeToContent(wide, label(500), label(500))
  assert(wide.w == M.MAX_WIDTH, "long text caps the width, got " .. tostring(wide.w))
  assert(wide.w == 240, "long text clamps the frame to 240 wide, got " .. tostring(wide.w))

  -- test_tiny_text_never_drops_below_min_width
  -- The padding, icon and dismiss button already exceed MIN_WIDTH, so the floor is the chrome itself.
  local narrow = frame()
  M.ResizeToContent(narrow, label(1), label(1))
  assert(narrow.w >= M.MIN_WIDTH, "tiny text keeps at least the minimum width, got " .. tostring(narrow.w))
  assert(narrow.w < M.MAX_WIDTH, "tiny text stays narrower than the maximum, got " .. tostring(narrow.w))

  -- test_a_long_detail_line_widens_the_frame
  local withDetail = frame()
  M.ResizeToContent(withDetail, label(1), label(1), label(500))
  assert(withDetail.w == M.MAX_WIDTH, "a long detail line widens the frame, got " .. tostring(withDetail.w))

  -- test_detail_label_gets_the_message_budget
  local budget
  local detail = label(1)
  detail.SetWidth = function(_self, w)
    budget = w
  end
  M.ResizeToContent(frame(), label(1), label(1), detail)
  assert(budget == M.MAX_WIDTH - M.LEFT_PAD - M.CLASS_ICON_SIZE - M.ICON_GAP - M.RIGHT_PAD, "detail gets the message budget")

  -- test_unmeasurable_detail_still_adds_one_row
  local tall = frame()
  tall.SetHeight = function(self, h)
    self.h = h
  end
  M.ResizeToContent(tall, label(1), label(1))
  assert(tall.h == M.HEIGHT, "two rows floor at HEIGHT, got " .. tostring(tall.h))
  M.ResizeToContent(tall, label(1), label(1), label(1))
  assert(tall.h == M.HEIGHT + M.DETAIL_ROW_HEIGHT, "the detail row adds one row, got " .. tostring(tall.h))

  -- test_reply_row_adds_its_height
  M.ResizeToContent(tall, label(1), label(1), nil, 28)
  assert(tall.h == M.HEIGHT + 28, "the reply row adds its height, got " .. tostring(tall.h))

  -- test_reply_row_widens_a_short_card
  assert(tall.w >= M.REPLY_MIN_WIDTH and tall.w <= M.MAX_WIDTH, "a short card widens for the reply row, got " .. tostring(tall.w))

  local function anchored()
    return {
      ClearAllPoints = function(self)
        self.point = nil
      end,
      SetPoint = function(self, ...)
        self.point = { ... }
      end,
    }
  end

  -- test_positioner_anchors_left_of_the_icon
  local card, icon = anchored(), {}
  M.NewPositioner(card, icon, nil).apply("left")
  local p = card.point
  assert(p[1] == "RIGHT" and p[2] == icon and p[3] == "LEFT" and p[4] == -M.GAP and p[5] == 0, "left anchors RIGHT to the icon's LEFT")

  -- test_positioner_falls_back_to_right_for_empty_or_nil
  M.NewPositioner(card, icon, nil).apply("")
  assert(card.point[1] == "LEFT" and card.point[3] == "RIGHT", "empty position falls back to right")
  local nilPositioner = M.NewPositioner(card, icon, nil)
  nilPositioner.apply("left")
  nilPositioner.apply(nil)
  assert(card.point[1] == "LEFT" and nilPositioner.resolve() == "right", "nil position falls back to right")

  -- test_positioner_resolves_the_getter_value
  assert(M.NewPositioner(card, icon, function()
    return "top"
  end).resolve() == "top", "resolve returns the getter's value")

  -- test_positioner_resolves_last_applied_when_the_getter_fails
  local failing = M.NewPositioner(card, icon, function()
    error("boom")
  end)
  failing.apply("below")
  assert(failing.resolve() == "below", "an erroring getter resolves to the last applied position")
  local blank = M.NewPositioner(card, icon, function()
    return ""
  end)
  blank.apply("left")
  assert(blank.resolve() == "left", "an empty getter resolves to the last applied position")
end
