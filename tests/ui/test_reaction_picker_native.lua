local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Localization = require("WhisperMessenger.Locale.Localization")
local ReactionAssets = require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local ReactionPicker = require("WhisperMessenger.UI.ChatBubble.ReactionPicker")
local PickerStyles = require("WhisperMessenger.UI.Shared.PickerStyles")
local Theme = require("WhisperMessenger.UI.Theme")

-- Under the Native WoW HUD the reaction picker (emoji tray + Reply / Copy
-- text) is a Blizzard tooltip frame with action-button and dropdown-menu art.

local SQUARE_HIGHLIGHT = "Interface\\Buttons\\ButtonHilight-Square"
local CHECKED_HIGHLIGHT = "Interface\\Buttons\\CheckButtonHilight"
local MENU_HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

local function assertBlizzardHighlight(button, path, label)
  local highlight = button.highlightTexture
  assert(type(highlight) == "table", label .. ": sets a highlight texture")
  assert(highlight.texturePath == path, label .. ": highlight art, got " .. tostring(highlight.texturePath))
  assert(highlight.blendMode == "ADD", label .. ": highlight blends additively")
  assert(highlight.drawLayer == "HIGHLIGHT", label .. ": highlight on the HIGHLIGHT layer")
end

local function hasFlatFill(frame)
  return FindUI.find(frame, function(node)
    return node.frameType == "Texture" and node.color ~= nil
  end) ~= nil
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local savedUIParent, savedSpecialFrames = _G.UIParent, _G.UISpecialFrames
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UISpecialFrames = {}
  local anchor = factory.CreateFrame("Button", nil, _G.UIParent)
  local selectedKey = ReactionAssets.KEYS[3]
  local message = { direction = "in", text = "hi", reaction = { key = selectedKey } }
  local noop = function() end

  Hud.Configure("classic")
  assert(ReactionPicker.Open(factory, anchor, message, noop, noop, nil, noop), "picker opens")
  Hud.Configure("off")
  local picker = ReactionPicker.GetFrame()

  -- test_hud_reaction_picker_is_a_tooltip_frame
  do
    assert(picker.template == "TooltipBackdropTemplate", "picker template, got " .. tostring(picker.template))
  end

  -- test_hud_emoji_hover_is_square_button_highlight
  do
    assertBlizzardHighlight(picker._reactionButtons[1], SQUARE_HIGHLIGHT, "emoji button")
  end

  -- test_hud_emoji_hover_paints_no_flat_fill
  do
    local button = picker._reactionButtons[1]
    button.scripts.OnEnter(button)
    assert(not button._selectedMark:IsShown(), "hover leaves the selected mark hidden")
    assert(not hasFlatFill(picker), "picker paints no flat colour")
    button.scripts.OnLeave(button)
  end

  -- test_hud_selected_reaction_uses_checked_art
  do
    local mark = picker._reactionButtons[3]._selectedMark
    assert(mark:IsShown(), "selected reaction is marked")
    assert(mark.texturePath == CHECKED_HIGHLIGHT, "selected art, got " .. tostring(mark.texturePath))
    assert(mark.blendMode == "ADD", "selected art blends additively")
  end

  -- test_hud_theme_refresh_keeps_selected_art
  do
    PickerStyles.ApplyPanelTheme(picker, picker._border)
    ReactionPicker.Open(factory, anchor, message, noop, noop, nil, noop)
    local mark = picker._reactionButtons[3]._selectedMark
    assert(mark.color == nil and mark.texturePath == CHECKED_HIGHLIGHT, "reopen keeps the selected art")
  end

  -- test_hud_reply_and_copy_use_dropdown_menu_art
  do
    assertBlizzardHighlight(picker._replyButton, MENU_HIGHLIGHT, "Reply")
    assertBlizzardHighlight(picker._copyButton, MENU_HIGHLIGHT, "Copy text")
  end

  -- test_hud_contents_clear_the_tooltip_border
  do
    local layout = ReactionAssets.GetPickerLayout()
    local inset = Theme.LAYOUT.NATIVE_BORDER_INSET
    local first = picker._reactionButtons[1].point
    assert(first[4] == 6 + inset and first[5] == -(5 + inset), "first emoji sits inside the border, got " .. first[4] .. "," .. first[5])
    assert(picker:GetWidth() == layout.frameWidth + inset * 2, "tray widens by the border on both sides")
    assert(picker:GetHeight() == layout.frameHeight + inset * 2, "tray grows by the border top and bottom")
    assert(picker._copyButton.point[5] == layout.copyOffsetY - inset, "Copy text row moves down with the grid")
  end

  ReactionPicker.Close()
  _G.UIParent, _G.UISpecialFrames = savedUIParent, savedSpecialFrames
end
