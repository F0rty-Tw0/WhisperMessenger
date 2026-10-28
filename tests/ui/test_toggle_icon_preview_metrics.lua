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
end
