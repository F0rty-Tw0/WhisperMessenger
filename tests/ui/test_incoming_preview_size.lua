local FakeUI = require("tests.helpers.fake_ui")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local IncomingPreview = require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")
local PreviewMetrics = require("WhisperMessenger.UI.ToggleIcon.PreviewMetrics")
local Theme = require("WhisperMessenger.UI.Theme")

-- Line heights in px at the default Font Size (sender 16pt, message 12pt) and
-- at the largest slider value (sender 21pt, message 17pt).
local DEFAULT_SENDER, DEFAULT_MESSAGE = 16, 12
local LARGE_SENDER, LARGE_MESSAGE = 21, 17
local TOOLTIP_BORDER = 5
local MIN_BELOW_TEXT = 8
local DEFAULT_HEIGHT = 56

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(48, 48)
  return IncomingPreview.Create(factory, parent, {})
end

local function fontObjectFor(key)
  return _G[Theme.FONTS[key]] or Theme.FONTS[key]
end

local function withHud(style, run)
  Hud.Configure(style)
  local ok, err = pcall(run)
  Hud.Configure("off")
  if not ok then
    error(err, 0)
  end
end

return function()
  local function test_sender_label_uses_the_header_name_font()
    local preview = build()
    assert(preview.senderLabel.fontObject == fontObjectFor("header_name"), "sender uses the large header font")
  end

  local function test_message_label_uses_the_message_text_font()
    local preview = build()
    assert(preview.messageLabel.fontObject == fontObjectFor("message_text"), "message uses the regular message font")
  end

  local function test_frame_height_is_the_preview_height_on_both_skins()
    for _, style in ipairs({ "off", "classic", "retail" }) do
      withHud(style, function()
        local preview = build()
        assert(preview.frame:GetHeight() == PreviewMetrics.HEIGHT, style .. ": frame height is HEIGHT")
      end)
    end
  end

  local function test_frame_starts_at_the_widest_width()
    local preview = build()
    assert(preview.frame:GetWidth() == 240, "frame width starts at 240, got " .. tostring(preview.frame:GetWidth()))
  end

  -- Shows a message with the given line heights; returns the fitted frame height and the text bottom.
  local function fittedWith(senderLine, messageLine)
    local preview = build()
    preview.senderLabel.lineHeight = senderLine
    preview.messageLabel.lineHeight = messageLine
    preview.setIncomingPreview("Jaina", "Hello there", "MAGE")
    local height = preview.frame:GetHeight()
    local textBottom = -PreviewMetrics.SENDER_TOP_OFFSET + senderLine - PreviewMetrics.MESSAGE_GAP + messageLine
    return height, textBottom
  end

  local function test_default_font_size_keeps_the_default_height()
    local height = fittedWith(DEFAULT_SENDER, DEFAULT_MESSAGE)
    assert(height == DEFAULT_HEIGHT, "default size keeps 56, got " .. tostring(height))
  end

  local function test_default_font_size_leaves_room_below_the_message_line()
    local height, textBottom = fittedWith(DEFAULT_SENDER, DEFAULT_MESSAGE)
    assert(height - textBottom - TOOLTIP_BORDER >= MIN_BELOW_TEXT, "room under the message past the border, got " .. (height - textBottom))
  end

  local function test_large_font_grows_the_frame_taller_than_the_default()
    local height = fittedWith(LARGE_SENDER, LARGE_MESSAGE)
    assert(height > DEFAULT_HEIGHT, "large font grows the frame, got " .. tostring(height))
  end

  local function test_large_font_keeps_room_below_the_message_line()
    local height, textBottom = fittedWith(LARGE_SENDER, LARGE_MESSAGE)
    assert(height - textBottom >= 14, "text bottom stays 14px above the frame bottom, got " .. (height - textBottom))
  end

  local function test_unmeasurable_text_falls_back_to_the_default_height()
    local frame = FakeUI.NewFactory().CreateFrame("Frame", nil, nil)
    frame:SetHeight(30)
    local blind = {
      SetWidth = function() end,
      GetStringWidth = function()
        return 10
      end,
    }
    PreviewMetrics.ResizeToContent(frame, blind, blind)
    assert(frame:GetHeight() == PreviewMetrics.HEIGHT, "falls back to HEIGHT, got " .. tostring(frame:GetHeight()))
  end

  local function test_text_block_clears_the_top_border()
    assert(-PreviewMetrics.SENDER_TOP_OFFSET > TOOLTIP_BORDER, "sender sits below the tooltip border")
  end

  local function test_close_button_sits_in_the_corner_just_inside_the_border()
    withHud("retail", function()
      local preview = build()
      local point, relativeTo, relativePoint, x, y = preview.dismissButton:GetPoint()
      assert(point == "TOPRIGHT" and relativeTo == preview.frame and relativePoint == "TOPRIGHT", "pinned to the top right")
      assert(x == -PreviewMetrics.DISMISS_INSET and y == -PreviewMetrics.DISMISS_INSET, "corner inset, got " .. tostring(x) .. "," .. tostring(y))
      assert(PreviewMetrics.DISMISS_INSET > TOOLTIP_BORDER, "clear of the tooltip border")
    end)
  end

  -- "×" at body size renders tiny; it gets its own larger font object.
  local function test_close_button_uses_a_large_multiplication_sign()
    local preview = build()
    assert(preview.dismissLabel:GetText() == "×", "got " .. tostring(preview.dismissLabel:GetText()))
    assert(preview.dismissLabel.fontObject == fontObjectFor("close_glyph"), "uses the close_glyph font")
  end

  test_close_button_sits_in_the_corner_just_inside_the_border()
  test_close_button_uses_a_large_multiplication_sign()
  test_sender_label_uses_the_header_name_font()
  test_message_label_uses_the_message_text_font()
  test_frame_height_is_the_preview_height_on_both_skins()
  test_frame_starts_at_the_widest_width()
  test_default_font_size_keeps_the_default_height()
  test_default_font_size_leaves_room_below_the_message_line()
  test_large_font_grows_the_frame_taller_than_the_default()
  test_large_font_keeps_room_below_the_message_line()
  test_unmeasurable_text_falls_back_to_the_default_height()
  test_text_block_clears_the_top_border()
end
