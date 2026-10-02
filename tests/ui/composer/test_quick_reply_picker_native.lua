local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local PickerStyles = require("WhisperMessenger.UI.Shared.PickerStyles")
local QuickReplyPicker = require("WhisperMessenger.UI.Composer.QuickReplyPicker")

-- Under the Native WoW HUD quick-reply rows look like dropdown-menu entries:
-- game font and Blizzard hover art, matching the other native popups.

local MENU_HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

local function hasFlatFill(frame)
  return FindUI.find(frame, function(node)
    return node.frameType == "Texture" and node.color ~= nil
  end) ~= nil
end

local function sameColor(a, b)
  return a ~= nil and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

local function openPicker(style)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  local anchor = factory.CreateFrame("Button", nil, parent)
  Hud.Configure(style)
  local picker = QuickReplyPicker.Create(factory, parent, anchor, function()
    return { "brb" }
  end, function() end)
  Hud.Configure("off")
  picker:open()
  return picker
end

return function()
  -- test_hud_row_hover_is_dropdown_menu_art
  do
    local row = openPicker("classic").rows[1]
    local highlight = row.highlightTexture
    assert(type(highlight) == "table", "HUD row sets a highlight texture")
    assert(highlight.texturePath == MENU_HIGHLIGHT, "highlight art, got " .. tostring(highlight.texturePath))
    assert(highlight.blendMode == "ADD", "highlight blends additively")
    assert(highlight.drawLayer == "HIGHLIGHT", "highlight on the HIGHLIGHT layer")
    assert(not hasFlatFill(row), "HUD row has no flat colour fill")
  end

  -- test_hud_row_uses_blizzard_font
  do
    local label = openPicker("classic").rows[1].label
    assert(label.fontObject == rawget(_G, "GameFontHighlight"), "HUD row font is GameFontHighlight")
    assert(label.textColor == nil, "HUD row keeps the font object's own colour")
    assert(label.text == "brb", "HUD row label")
  end

  -- test_hud_theme_refresh_keeps_native_rows
  do
    local picker = openPicker("classic")
    picker:refreshTheme()
    local row = picker.rows[1]
    assert(not hasFlatFill(row), "refreshed HUD row paints no flat colour")
    assert(row.label.textColor == nil, "refreshed HUD row keeps the font colour")
    assert(row.highlightTexture.texturePath == MENU_HIGHLIGHT, "refresh keeps the highlight art")
  end

  -- test_hud_rows_clear_the_tooltip_border
  do
    local picker = openPicker("classic")
    local pad = 6 + Theme.LAYOUT.NATIVE_BORDER_INSET
    local first = picker.rows[1].point
    assert(first[4] == pad and first[5] == -pad, "first row sits inside the border, got " .. first[4] .. "," .. first[5])
    assert(picker.frame:GetWidth() == picker.rows[1]:GetWidth() + pad * 2, "picker widens by the border on both sides")
  end

  -- test_modern_row_keeps_flat_hover
  do
    local row = openPicker("off").rows[1]
    assert(row.highlightTexture == nil, "modern row sets no Blizzard highlight")
    row.scripts.OnEnter(row)
    assert(row._highlight:IsShown(), "modern hover shows the themed fill")
    assert(sameColor(row._highlight.color, PickerStyles.HighlightColor(0.35)), "modern hover colour")
    assert(row.label.textColor ~= nil, "modern row label uses the theme colour")
  end
end
