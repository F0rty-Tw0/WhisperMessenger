local FakeUI = require("tests.helpers.fake_ui")
local IncomingPreview = require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")
local PreviewMetrics = require("WhisperMessenger.UI.ToggleIcon.PreviewMetrics")
local Theme = require("WhisperMessenger.UI.Theme")

-- Line heights in px at the default Font Size: sender 16pt, message and detail 12pt.
local SENDER_LINE, MESSAGE_LINE = 16, 12
local DEFAULT_HEIGHT = 56
local DETAIL = "Your alt Artio can craft it"

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(48, 48)
  parent:Show()
  local preview = IncomingPreview.Create(factory, parent, {})
  preview.senderLabel.lineHeight = SENDER_LINE
  preview.messageLabel.lineHeight = MESSAGE_LINE
  preview.detailLabel.lineHeight = MESSAGE_LINE
  return preview
end

local function noop() end

local function entry(detail)
  return {
    sender = "Customer",
    text = "WTB Plate Belt",
    classTag = "WARRIOR",
    detail = detail,
    onClick = noop,
    onDismiss = noop,
    onShown = noop,
  }
end

local function fontObjectFor(key)
  return _G[Theme.FONTS[key]] or Theme.FONTS[key]
end

local function sameColor(a, b)
  return a ~= nil and b ~= nil and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

return function()
  local function test_detail_row_is_hidden_before_any_preview()
    local p = build()
    assert(p.detailLabel:IsShown() == false, "detail row starts hidden")
  end

  local function test_detail_row_is_a_single_message_font_line_under_the_message()
    local p = build()
    assert(p.detailLabel.fontObject == fontObjectFor("message_text"), "detail uses the message font")
    assert(p.detailLabel.wordWrap == false and p.detailLabel.maxLines == 1, "detail is one line")
    local point, relativeTo, relativePoint, x, y = p.detailLabel:GetPoint()
    assert(point == "TOPLEFT" and relativeTo == p.messageLabel and relativePoint == "BOTTOMLEFT", "detail hangs under the message")
    assert(x == 0 and y == PreviewMetrics.DETAIL_GAP, "detail sits one gap below, got " .. tostring(x) .. "," .. tostring(y))
  end

  local function test_external_detail_shows_a_third_row()
    local p = build()
    p.setExternalPreview(entry(DETAIL))
    assert(p.detailLabel:IsShown() == true and p.detailLabel.text == DETAIL, "detail row shows the detail text")
    assert(p.senderLabel.text == "Customer" and p.messageLabel.text == "WTB Plate Belt", "the two rows keep their text")
  end

  local function test_external_detail_grows_the_frame_by_one_row()
    local p = build()
    p.setExternalPreview(entry(DETAIL))
    local height = p.frame:GetHeight()
    assert(height == DEFAULT_HEIGHT + PreviewMetrics.DETAIL_ROW_HEIGHT, "one row taller, got " .. tostring(height))
  end

  local function test_detail_row_fits_with_room_below()
    local p = build()
    p.setExternalPreview(entry(DETAIL))
    local textBottom = -PreviewMetrics.SENDER_TOP_OFFSET
      + SENDER_LINE
      - PreviewMetrics.MESSAGE_GAP
      + MESSAGE_LINE
      - PreviewMetrics.DETAIL_GAP
      + MESSAGE_LINE
    assert(p.frame:GetHeight() - textBottom >= PreviewMetrics.BOTTOM_ROOM, "room under the detail line")
  end

  -- At the largest Font Size (sender 21pt, message and detail 17pt) the lines outgrow the
  -- floor, so the frame grows to the measured detail line plus the room below it.
  local function test_detail_row_fits_at_the_largest_font_size()
    local p = build()
    p.senderLabel.lineHeight, p.messageLabel.lineHeight, p.detailLabel.lineHeight = 21, 17, 17
    p.setExternalPreview(entry(DETAIL))
    local textBottom = -PreviewMetrics.SENDER_TOP_OFFSET + 21 - PreviewMetrics.MESSAGE_GAP + 17 - PreviewMetrics.DETAIL_GAP + 17
    local height = p.frame:GetHeight()
    assert(height == textBottom + PreviewMetrics.BOTTOM_ROOM, "fits the measured detail line, got " .. tostring(height))
  end

  local function test_external_without_detail_keeps_the_two_row_height()
    local p = build()
    p.setExternalPreview(entry(nil))
    assert(p.detailLabel:IsShown() == false, "no detail, no third row")
    assert(p.frame:GetHeight() == DEFAULT_HEIGHT, "two-row height, got " .. tostring(p.frame:GetHeight()))
  end

  local function test_empty_detail_keeps_the_two_row_height()
    local p = build()
    p.setExternalPreview(entry(""))
    assert(p.detailLabel:IsShown() == false, "empty detail, no third row")
    assert(p.frame:GetHeight() == DEFAULT_HEIGHT, "two-row height, got " .. tostring(p.frame:GetHeight()))
  end

  local function test_class_icon_stays_vertically_centred_with_detail()
    local p = build()
    p.setExternalPreview(entry(DETAIL))
    local point, relativeTo, relativePoint, _x, y = p.classIconFrame:GetPoint()
    assert(point == "LEFT" and relativeTo == p.frame and relativePoint == "LEFT" and y == 0, "icon centred on the frame's left edge")
  end

  local function test_whisper_after_detail_hides_the_row_and_restores_height()
    local p = build()
    p.setExternalPreview(entry(DETAIL))
    p.setIncomingPreview("Jaina", "Hello there", "MAGE")
    assert(p.detailLabel:IsShown() == false and p.detailLabel.text == "", "own whisper has no detail row")
    assert(p.frame:GetHeight() == DEFAULT_HEIGHT, "own whisper keeps two rows, got " .. tostring(p.frame:GetHeight()))
  end

  local function test_clear_hides_the_detail_row()
    local p = build()
    p.setExternalPreview(entry(DETAIL))
    p.setExternalPreview(nil)
    assert(p.detailLabel:IsShown() == false and p.detailLabel.text == "", "clear hides the detail row")
  end

  local function test_a_second_external_without_detail_hides_the_row()
    local p = build()
    p.setExternalPreview(entry(DETAIL))
    p.setExternalPreview(entry(nil))
    assert(p.detailLabel:IsShown() == false, "the newer preview has no detail")
    assert(p.frame:GetHeight() == DEFAULT_HEIGHT, "back to two rows, got " .. tostring(p.frame:GetHeight()))
  end

  local function test_theme_paints_the_detail_like_the_message()
    local p = build()
    p.setExternalPreview(entry(DETAIL))
    p.applyTheme(Theme)
    assert(sameColor(p.detailLabel.textColor, Theme.COLORS.text_secondary), "detail takes text_secondary")
  end

  test_detail_row_is_hidden_before_any_preview()
  test_detail_row_is_a_single_message_font_line_under_the_message()
  test_external_detail_shows_a_third_row()
  test_external_detail_grows_the_frame_by_one_row()
  test_detail_row_fits_with_room_below()
  test_detail_row_fits_at_the_largest_font_size()
  test_external_without_detail_keeps_the_two_row_height()
  test_empty_detail_keeps_the_two_row_height()
  test_class_icon_stays_vertically_centred_with_detail()
  test_whisper_after_detail_hides_the_row_and_restores_height()
  test_clear_hides_the_detail_row()
  test_a_second_external_without_detail_hides_the_row()
  test_theme_paints_the_detail_like_the_message()
end
