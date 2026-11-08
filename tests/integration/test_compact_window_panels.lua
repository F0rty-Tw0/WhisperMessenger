local CompactWindow = require("tests.helpers.compact_window")
local Theme = require("WhisperMessenger.UI.Theme")

local function noop() end

-- Frame open, three panels registered: "plain" (no flag), "slim" and "slim2"
-- (compact). Returns the window and the size before any panel widened it.
local function build(extra, inChat)
  local case = CompactWindow.Build(extra)
  local window = case.window
  window.frame:Show()
  window.registerPanel("plain", { title = "Plain", onShow = noop })
  window.registerPanel("slim", { title = "Slim", onShow = noop, compact = true })
  window.registerPanel("slim2", { title = "Slim two", onShow = noop, compact = true })
  if inChat then
    CompactWindow.Select(case, "a")
    CompactWindow.FinishSlide(case)
  end
  return window, window.frame.width, window.frame.height
end

return function()
  -- test_non_compact_panel_widens_the_window_and_closing_restores_it (row 1)
  -- test_compact_panel_leaves_the_window_narrow (row 2)
  for _, inChat in ipairs({ false, true }) do
    local where = inChat and " in a chat" or " on the list"
    local window, narrow, height = build(nil, inChat)
    local frame = window.frame
    window.showPanel("plain")
    assert(frame.width == Theme.WINDOW_WIDTH, "non-compact widens" .. where .. ", got " .. frame.width)
    window.hidePanel()
    assert(frame.width == narrow and frame.height == height, "closing restores" .. where)
    window.showPanel("slim")
    assert(frame.width == narrow and frame.height == height, "compact stays narrow" .. where .. ", got " .. frame.width)
  end

  -- test_switching_from_a_wide_panel_to_a_compact_one_narrows (row 3)
  do
    local window, narrow, height = build()
    window.showPanel("plain")
    window.showPanel("slim")
    assert(window.frame.width == narrow and window.frame.height == height, "got " .. window.frame.width)
  end

  -- test_switching_from_a_compact_panel_to_a_plain_one_widens (row 4)
  do
    local window = build()
    window.showPanel("slim")
    window.showPanel("plain")
    assert(window.frame.width == Theme.WINDOW_WIDTH, "got " .. window.frame.width)
  end

  -- test_settings_over_a_compact_panel_widen_and_closing_restores (row 5)
  do
    local window, narrow = build()
    window.showPanel("slim")
    window.setOptionsVisible(true)
    assert(window.frame.width == Theme.WINDOW_WIDTH, "settings widen, got " .. window.frame.width)
    window.setOptionsVisible(false)
    assert(window.frame.width == narrow, "back to the pre-widen size, got " .. window.frame.width)
  end

  -- test_a_compact_panel_over_settings_narrows (row 6)
  do
    local window, narrow = build()
    window.setOptionsVisible(true)
    window.showPanel("slim")
    assert(window.frame.width == narrow, "got " .. window.frame.width)
  end

  -- test_closing_a_compact_panel_keeps_the_size (row 7)
  do
    local window, narrow, height = build()
    window.showPanel("slim")
    window.hidePanel()
    assert(window.frame.width == narrow and window.frame.height == height, "got " .. window.frame.width)
  end

  -- test_compact_then_plain_then_compact_ends_at_the_pre_widen_width
  do
    local window, narrow, height = build()
    local frame = window.frame
    for round = 1, 3 do
      window.showPanel("slim")
      window.showPanel("plain")
      window.showPanel("slim2")
      assert(frame.width == narrow and frame.height == height, "round " .. round .. " drifted to " .. frame.width)
    end
    window.hidePanel()
    assert(frame.width == narrow, "closed at the pre-widen width, got " .. frame.width)
  end

  -- test_classic_window_ignores_the_flag
  do
    local window, size = build({ compactLayout = false })
    window.showPanel("slim")
    assert(window.frame.width == size, "compact: size untouched, got " .. window.frame.width)
    window.showPanel("plain")
    assert(window.frame.width == size, "plain: size untouched, got " .. window.frame.width)
  end
end
