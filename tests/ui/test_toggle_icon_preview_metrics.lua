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

  -- test_tiny_text_keeps_min_width
  local narrow = frame()
  M.ResizeToContent(narrow, label(1), label(1))
  assert(narrow.w == M.MIN_WIDTH, "tiny text keeps the minimum width, got " .. tostring(narrow.w))
end
