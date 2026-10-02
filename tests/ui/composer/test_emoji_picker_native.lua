local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local ReactionAssets = require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local EmojiPicker = require("WhisperMessenger.UI.Composer.EmojiPicker")

-- Under the Native WoW HUD the composer emoji picker is a Blizzard tooltip
-- frame and its cells use the action-button hover art.

local SQUARE_HIGHLIGHT = "Interface\\Buttons\\ButtonHilight-Square"

local function hasFlatFill(frame)
  return FindUI.find(frame, function(node)
    return node.frameType == "Texture" and node.color ~= nil
  end) ~= nil
end

local function createPicker(style)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  local anchor = factory.CreateFrame("Button", nil, parent)
  Hud.Configure(style)
  local picker = EmojiPicker.Create(factory, parent, anchor, function() end)
  Hud.Configure("off")
  return picker
end

return function()
  -- test_hud_emoji_picker_is_a_tooltip_frame
  do
    local picker = createPicker("classic")
    assert(picker.frame.template == "TooltipBackdropTemplate", "picker template, got " .. tostring(picker.frame.template))
  end

  -- test_hud_emoji_cell_hover_is_square_button_highlight
  do
    local button = createPicker("classic").buttons[1]
    local highlight = button.highlightTexture
    assert(type(highlight) == "table", "emoji cell sets a highlight texture")
    assert(highlight.texturePath == SQUARE_HIGHLIGHT, "highlight art, got " .. tostring(highlight.texturePath))
    assert(highlight.blendMode == "ADD", "highlight blends additively")
    assert(highlight.drawLayer == "HIGHLIGHT", "highlight on the HIGHLIGHT layer")
  end

  -- test_hud_theme_refresh_paints_no_flat_fill
  do
    local picker = createPicker("classic")
    picker:refreshTheme()
    assert(not hasFlatFill(picker.frame), "refreshed picker paints no flat colour")
    assert(picker.buttons[1]._highlight.texturePath == SQUARE_HIGHLIGHT, "refresh keeps the highlight art")
  end

  -- test_hud_cells_clear_the_tooltip_border
  do
    local picker = createPicker("classic")
    local layout = ReactionAssets.GetPickerLayout()
    local inset = Theme.LAYOUT.NATIVE_BORDER_INSET
    local first = picker.buttons[1].point
    assert(first[4] == 6 + inset and first[5] == -(6 + inset), "first cell sits inside the border, got " .. first[4] .. "," .. first[5])
    assert(picker.frame:GetWidth() == layout.frameWidth + inset * 2, "picker widens by the border on both sides")
    assert(picker.frame:GetHeight() == layout.buttonSize * layout.rows + 12 + inset * 2, "picker grows by the border top and bottom")
  end

  -- test_modern_emoji_cell_keeps_flat_hover
  do
    local button = createPicker("off").buttons[1]
    assert(button.highlightTexture == nil, "modern cell sets no Blizzard highlight")
    assert(button._highlight.color ~= nil, "modern cell hover is a themed fill")
  end
end
