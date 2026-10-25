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
end
