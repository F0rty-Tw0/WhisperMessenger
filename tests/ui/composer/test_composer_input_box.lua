local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Composer = require("WhisperMessenger.UI.Composer")
local RetailHud = require("tests.helpers.retail_hud")

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

local function build(factory, options)
  Fonts.Initialize("default")
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, Theme.COMPOSER_HEIGHT)
  return Composer.Create(factory, parent, CONTACT, function() end, nil, nil, nil, options)
end

local function assertInsets(input, expected, label)
  local ins = input.textInsets or {}
  for i = 1, 4 do
    assert(ins[i] == expected[i], label .. ": text inset " .. i .. " is " .. expected[i] .. ", got " .. tostring(ins[i]))
  end
end

-- Textures on `frame`; hiddenToo also counts the template art hidden at create.
local function textureCount(frame, hiddenToo)
  local count = 0
  for _, child in ipairs(frame.children or {}) do
    if child.frameType == "Texture" and (hiddenToo or child.shown) then
      count = count + 1
    end
  end
  return count
end

-- The scroll frame is `rows` lines plus 3px slack above and below, 5px below
-- the box top, so the text itself still starts 8px down.
local function assertViewport(composer, rows, label)
  local scroll = composer.scroll
  local expected = rows * 12 + 6
  assert(scroll.height == expected, label .. ": viewport is " .. expected .. " tall, got " .. tostring(scroll.height))
  local top = lastPoint(scroll, "TOPLEFT")
  assert(top and top[2] == composer.box and top[4] == 0 and top[5] == -5, label .. ": viewport starts 5px into the box")
  local right = lastPoint(scroll, "TOPRIGHT")
  assert(right and right[2] == composer.box and right[4] == 0 and right[5] == -5, label .. ": viewport spans the box width")
end

return function()
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_default")

  -- test_composer_types_in_blizzards_input_scroll_box
  do
    local composer = build(FakeUI.NewFactory({ wrap = true }))
    assert(composer.scroll.template == "InputScrollFrameTemplate", "the text scrolls in Blizzard's input scroll frame")
    assert(composer.input == composer.scroll.EditBox, "the player types in the template's edit box")
    assert(composer.scroll:GetParent() == composer.box, "the scroll frame sits inside the box")
  end

  -- test_template_input_is_multi_line_with_no_letter_cap
  do
    local input = build(FakeUI.NewFactory({ wrap = true })).input
    assert(input.multiline == true, "the template box is multi-line")
    assert(input.maxLetters == 0, "only the byte cap applies, got maxLetters " .. tostring(input.maxLetters))
  end

  -- test_template_art_and_char_count_are_hidden
  do
    local box = build(FakeUI.NewFactory({ wrap = true })).scroll
    assert(box.CharCount.shown == false, "the template's character count is hidden")
    assert(box.TopTex.shown == false, "the template's border art is hidden")
  end

  -- test_template_scroll_bar_stays_hidden
  do
    local bar = build(FakeUI.NewFactory({ wrap = true })).scroll.ScrollBar
    bar:Show()
    assert(bar:IsShown() == false, "the scroll bar hides again when the template shows it")
  end

  -- test_template_text_handler_still_runs_before_ours
  do
    local drafts = {}
    local composer = build(FakeUI.NewFactory({ wrap = true }), {
      onDraftChanged = function(key, text)
        drafts[#drafts + 1] = { key = key, text = text }
      end,
    })
    local input = composer.input
    local before = input.templateTextChanges
    input:SetText("hello")
    input.scripts.OnTextChanged(input, true)
    assert(input.templateTextChanges == before + 1, "the template's own text handler ran")
    local last = drafts[#drafts]
    assert(last and last.key == CONTACT.conversationKey and last.text == "hello", "the draft got the typed text")
  end

  -- test_one_row_box_looks_as_today
  do
    local composer = build(FakeUI.NewFactory({ wrap = true }))
    local box, input = composer.box, composer.input
    assert(box.height == 28, "one row is 28 tall, got " .. tostring(box.height))
    local point = lastPoint(box, "BOTTOMLEFT")
    assert(point and point[4] == 8 and point[5] == 8, "the box sits in the 8px gutter")
    -- The text line starts 8px below the box top, as the old 8px text inset put it.
    assertViewport(composer, 1, "one row")
    assertInsets(input, { 8, 8, 3, 3 }, "template")
  end

  -- test_text_viewport_stops_at_the_row_cap
  do
    local composer = build(FakeUI.NewFactory({ wrap = true }))
    composer.input:SetText(("a"):rep(300))
    composer.input.scripts.OnTextChanged(composer.input, true)
    assert(composer.box.height == 40, "two rows is 40 tall, got " .. tostring(composer.box.height))
    -- Past the cap the template scrolls the text; the padding must not scroll with it.
    assertViewport(composer, 2, "row cap")
    assertInsets(composer.input, { 8, 8, 3, 3 }, "row cap")
  end

  -- test_typing_does_not_reset_the_text_insets
  -- In game, SetTextInsets on the focused box hides its cursor, even with the same values.
  do
    local composer = build(FakeUI.NewFactory({ wrap = true }))
    local input = composer.input
    local insetCalls = {}
    local setTextInsets = input.SetTextInsets
    input.SetTextInsets = function(self, ...)
      insetCalls[#insetCalls + 1] = { ... }
      return setTextInsets(self, ...)
    end
    for count = 1, 5 do
      input:SetText(("a"):rep(count))
      input.scripts.OnTextChanged(input, true)
    end
    assert(#insetCalls == 0, "typing at one row leaves the insets alone, got " .. #insetCalls .. " calls")
    Fonts.SetFontSize(24)
    composer.remeasure()
    Fonts.SetFontSize(12)
    assert(#insetCalls == 1, "a font size that shrinks the slack resets the insets once, got " .. #insetCalls)
    assertInsets(input, { 8, 8, 2, 2 }, "24px font")
  end

  -- test_surfaces_draw_on_the_box_not_the_scrolling_frame
  for _, nativeChrome in ipairs({ false, true }) do
    local composer = build(FakeUI.NewFactory({ wrap = true }), { nativeChrome = nativeChrome })
    local label = nativeChrome and "native" or "modern"
    assert(composer.scroll ~= composer.box, label .. ": the box is a holder around the scroll frame")
    assert(textureCount(composer.scroll, false) == 0, label .. ": nothing shows on the scroll frame")
    -- The fake template makes one art texture (TopTex); nothing of ours joins it.
    assert(textureCount(composer.scroll, true) == 1, label .. ": no surface texture on the scroll frame")
    assert(textureCount(composer.box, true) > 0, label .. ": the surface is drawn on the box")
  end

  -- test_clicking_the_box_padding_focuses_the_input
  do
    local composer = build(FakeUI.NewFactory({ wrap = true }))
    assert(composer.box.mouseEnabled == true, "the box takes clicks on its padding")
    composer.box.scripts.OnMouseDown(composer.box, "LeftButton")
    assert(composer.input:HasFocus(), "a click on the padding focuses the input")
  end

  -- test_placeholder_sits_on_the_box
  do
    local composer = build(FakeUI.NewFactory({ wrap = true }))
    local placeholder = composer.placeholder
    assert(placeholder:GetParent() == composer.input, "the placeholder draws above the fill, on the input")
    local point = lastPoint(placeholder, "LEFT")
    assert(point and point[2] == composer.box and point[4] == 8, "the placeholder is anchored 8px into the box")
  end

  -- test_template_input_starts_on_the_base_font
  do
    local composer = build(FakeUI.NewFactory({ fontColors = true }))
    assert(composer.input:GetFontObject() == rawget(_G, "WM_ChatNormal"), "the template box is on the base font")
  end

  -- test_client_without_template_keeps_a_plain_edit_box
  do
    local factory = RetailHud.Factory(FakeUI, { missing = { InputScrollFrameTemplate = true } })
    local composer = build(factory)
    assert(composer.box == composer.input, "the plain edit box is the box")
    assert(composer.scroll == nil, "no scroll frame without the template")
    assert(composer.input.frameType == "EditBox", "a plain edit box")
    assert(composer.input.multiline ~= true, "the plain edit box stays single-line")
    assertInsets(composer.input, { 8, 8, 4, 4 }, "fallback")
  end

  Fonts.Initialize("default")
  Theme.SetPreset(previousPreset)
  print("PASS: test_composer_input_box")
end
