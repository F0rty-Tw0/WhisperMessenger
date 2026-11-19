local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ComposerRelayout = require("WhisperMessenger.UI.Composer.ComposerRelayout")

-- Fake composer parts on a 600px pane, plus a rows stub that records each fit width.
local function setup(getButtonCount)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 44)
  local function mk()
    return factory.CreateFrame("Frame", nil, parent)
  end
  local parts = {
    pane = parent,
    box = mk(),
    scroll = mk(),
    input = mk(),
    sendButton = mk(),
    emojiButton = mk(),
    emojiIcon = mk(),
    quickReplyButton = mk(),
  }
  parts.quickReplyButton.icon = mk()
  local env = { fits = {}, heights = {}, nextCount = 1, nextHeight = 44 }
  local rows = {
    fit = function(_text, width)
      env.fits[#env.fits + 1] = width
      return env.nextCount, env.nextHeight
    end,
    lineHeight = function()
      return 12
    end,
  }
  env.parent, env.parts = parent, parts
  env.relayout = ComposerRelayout.Create({
    parent = parent,
    pane = parent,
    parts = parts,
    rows = rows,
    input = factory.CreateFrame("EditBox", nil, parent),
    multiLine = false,
    onHeightChanged = function(height)
      env.heights[#env.heights + 1] = height
    end,
    getButtonCount = getButtonCount,
  })
  return env
end

local function two()
  return 2
end

return function()
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_default")

  -- test_create_lays_out_one_row_for_three_buttons
  do
    local env = setup()
    assert(env.parts.box.width == 494, "three buttons leave a 494px box, got " .. tostring(env.parts.box.width))
  end

  -- test_create_uses_the_button_count
  do
    local env = setup(two)
    assert(env.parts.box.width == 524, "two buttons leave a 524px box, got " .. tostring(env.parts.box.width))
  end

  -- test_refresh_fits_rows_on_the_counted_text_width
  do
    local env = setup(two)
    env.relayout.refresh()
    assert(env.fits[#env.fits] == 508, "rows fit on 508px, got " .. tostring(env.fits[#env.fits]))
  end

  -- test_refresh_reads_the_count_each_time
  do
    local count = 3
    local env = setup(function()
      return count
    end)
    env.relayout.refresh()
    local first = env.fits[#env.fits]
    count = 2
    env.relayout.refresh()
    local second = env.fits[#env.fits]
    assert(first == 478 and second == 508, "fit width follows the live count, got " .. tostring(first) .. "/" .. tostring(second))
  end

  -- test_new_height_is_reported_once
  do
    local env = setup()
    env.nextHeight = 56
    env.relayout.refresh()
    env.relayout.refresh()
    assert(#env.heights == 1 and env.heights[1] == 56, "56 reported once, got " .. #env.heights .. " reports")
    assert(env.relayout.getHeight() == 56, "getHeight is the reported height")
  end

  -- test_resize_ignores_a_zero_width
  do
    local env = setup()
    local before = #env.fits
    env.parent:SetSize(0, 44)
    env.relayout.resize(0)
    assert(#env.fits == before, "a zero width does not relayout")
  end

  Theme.SetPreset(previousPreset)
end
