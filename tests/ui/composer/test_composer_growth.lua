local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Composer = require("WhisperMessenger.UI.Composer")

local CONTACT = { conversationKey = "me::WOW::a", displayName = "A", channel = "WOW" }

-- Last SetPoint for `anchor` (WoW replaces per anchor).
local function lastPoint(region, anchor)
  local found
  for _, pt in ipairs(region.points or {}) do
    if pt[1] == anchor then
      found = pt
    end
  end
  return found
end

local function build(factory)
  Fonts.Initialize("default")
  factory = factory or FakeUI.NewFactory({ wrap = true })
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 44)
  local heights = {}
  local composer = Composer.Create(factory, parent, CONTACT, function() end, nil, nil, nil, {
    onHeightChanged = function(height)
      heights[#heights + 1] = height
    end,
  })
  return composer, heights, parent
end

local function typeChars(composer, count)
  composer.input:SetText(("a"):rep(count))
  composer.input.scripts.OnTextChanged(composer.input, true)
end

return function()
  -- test_one_row_keeps_the_bar_at_44
  do
    local composer, heights = build()
    assert(composer.getHeight() == 44, "one row is a 44 bar, got " .. tostring(composer.getHeight()))
    assert(composer.box.height == 28, "one row box is 28 tall, got " .. tostring(composer.box.height))
    assert(#heights == 0, "no report while the bar stays at 44")
  end

  -- test_long_text_grows_to_two_rows
  do
    local composer, heights = build()
    typeChars(composer, 100)
    assert(#heights == 1 and heights[1] == 56, "two rows report a 56 bar, got " .. table.concat(heights, ","))
    assert(composer.getHeight() == 56, "getHeight follows the bar")
    assert(composer.box.height == 40, "two row box is 40 tall, got " .. tostring(composer.box.height))
  end

  -- test_text_past_two_rows_stays_at_two
  do
    local composer, heights = build()
    typeChars(composer, 100)
    local reports = #heights
    typeChars(composer, 300)
    assert(#heights == reports, "past two rows nothing new is reported")
    assert(composer.getHeight() == 56, "the bar stays at 56, got " .. tostring(composer.getHeight()))
    assert(composer.box.height == 40, "the box stays two rows tall, got " .. tostring(composer.box.height))
  end

  -- test_same_text_again_reports_nothing
  do
    local composer, heights = build()
    typeChars(composer, 100)
    typeChars(composer, 100)
    assert(#heights == 1, "a repeat with the same text reports once, got " .. #heights)
  end

  -- test_buttons_stay_at_the_bottom
  do
    local composer = build()
    typeChars(composer, 100)
    local point = lastPoint(composer.sendButton, "BOTTOMRIGHT")
    assert(point and point[5] == 9, "send button stays 9 up from the bottom, got " .. tostring(point and point[5]))
  end

  -- test_send_shrinks_back_to_one_row
  do
    local composer, heights = build()
    typeChars(composer, 100)
    composer.input.scripts.OnEnterPressed(composer.input)
    assert(heights[#heights] == 44, "sending reports the 44 bar, got " .. tostring(heights[#heights]))
    assert(composer.box.height == 28, "the box is one row again, got " .. tostring(composer.box.height))
  end

  -- test_draft_load_recomputes_rows
  do
    local composer, heights = build()
    composer.loadDraft(("a"):rep(100))
    assert(heights[#heights] == 56, "a long draft opens at two rows, got " .. tostring(heights[#heights]))
  end

  -- test_relayout_cap_limits_rows
  do
    local composer, heights = build()
    typeChars(composer, 100)
    composer.relayout(600, 50)
    assert(heights[#heights] == 44, "a 50 cap holds one row, got " .. tostring(heights[#heights]))
    composer.relayout(600, nil)
    assert(heights[#heights] == 56, "no cap gives two rows back, got " .. tostring(heights[#heights]))
  end

  -- test_narrower_pane_adds_rows
  do
    local composer, heights, parent = build()
    typeChars(composer, 60)
    assert(#heights == 0, "60 chars fit one row at 600 wide")
    parent:SetSize(300, 44)
    composer.relayout(300)
    assert(heights[#heights] == 56, "60 chars take two rows at 300 wide, got " .. tostring(heights[#heights]))
  end

  -- test_font_size_change_resizes_the_bar_at_the_same_row_count
  do
    local composer, heights = build()
    typeChars(composer, 100)
    Fonts.SetFontSize(16)
    composer.remeasure()
    Fonts.SetFontSize(12)
    assert(heights[#heights] == 60, "two 16 px rows make a 60 bar, got " .. tostring(heights[#heights]))
  end

  -- test_reshown_composer_recomputes_rows
  do
    local composer, heights = build()
    composer.frame:Hide()
    composer.input:SetText(("a"):rep(100))
    composer.frame:Show()
    assert(heights[#heights] == 56, "showing the composer remeasures, got " .. tostring(heights[#heights]))
  end

  -- test_remeasuring_on_show_keeps_the_send_focus_hook
  do
    local composer = build()
    local hooks = composer.frame._hookScripts and composer.frame._hookScripts.OnShow or {}
    -- Send focus hooks OnShow first; ours must sit beside it, not replace it.
    assert(#hooks == 2, "the pane keeps send focus's OnShow hook and ours, got " .. #hooks)
  end

  -- test_viewport_matches_the_measured_line_pitch
  do
    -- Retail lays 11 px text out 10.67 px apart; a font-size viewport would
    -- show a sliver of the line scrolled out above.
    local pitch = 32 / 3
    local composer = build()
    local measurer
    for _, child in ipairs(composer.frame.children or {}) do
      if child.frameType == "FontString" and child.wordWrap == true and not child.shown then
        measurer = child
      end
    end
    assert(measurer, "the composer has a hidden word-wrap measurer")
    measurer.GetStringHeight = function(self)
      return self:GetNumLines() * pitch
    end
    typeChars(composer, 300)
    local height = composer.scroll.height - 6
    assert(height > 20 and height <= 2 * pitch + 1e-9, "two rows of 10.67 px make a 21.33 viewport plus slack, got " .. tostring(height))
  end

  -- test_fallback_box_never_grows
  do
    local factory = FakeUI.NewFactory({ wrap = true })
    local create = factory.CreateFrame
    factory.CreateFrame = function(frameType, name, parent, template)
      if template == "InputScrollFrameTemplate" then
        error("Couldn't find inherited node: " .. template)
      end
      return create(frameType, name, parent, template)
    end
    local composer, heights = build(factory)
    typeChars(composer, 300)
    assert(composer.getHeight() == 44, "a plain edit box keeps one row, got " .. tostring(composer.getHeight()))
    assert(#heights == 0, "no growth is reported")
  end

  Fonts.Initialize("default")
  print("PASS: test_composer_growth")
end
