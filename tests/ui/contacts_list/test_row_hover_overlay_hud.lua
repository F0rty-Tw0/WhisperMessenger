local ContactsList = require("WhisperMessenger.UI.ContactsList")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local SELECTED_ART = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight"

local function item(name, extra)
  local result = {
    conversationKey = "me::WOW::" .. name,
    displayName = name,
    lastPreview = "hello",
    unreadCount = 0,
    lastActivityAt = 100,
    channel = "WOW",
    pinned = false,
  }
  for key, value in pairs(extra or {}) do
    result[key] = value
  end
  return result
end

local ITEMS = {
  item("alice"),
  item("bob", { pinned = true }),
  item("guild", { channel = "GUILD" }),
}

local OPTIONS = {
  onSelect = function() end,
  onPin = function() end,
  onRemove = function() end,
}

local function refresh(factory, parent, rows, selectedKey)
  OPTIONS.selectedConversationKey = selectedKey
  OPTIONS.visibleCount = #ITEMS
  return ContactsList.Refresh(factory, parent, rows, ITEMS, OPTIONS)
end

local function rgbMatches(actual, expected)
  return actual ~= nil and actual[1] == expected[1] and actual[2] == expected[2] and actual[3] == expected[3]
end

local function isClear(texture)
  return texture.color == nil or (texture.color[4] or 1) == 0
end

local function assertNativeArt(texture, path, label)
  assert(texture.texturePath == path, label .. ": Blizzard art " .. path .. ", got " .. tostring(texture.texturePath))
  assert(texture.blendMode == "ADD", label .. ": additive blend")
  assert(texture._wmNativeArt == true, label .. ": flagged as native art")
  assert(texture.color == nil, label .. ": no flat colour fill")
end

return function()
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_default")
  Hud.Configure("classic")

  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)
  local rows = refresh(factory, parent, {}, ITEMS[1].conversationKey)
  local selected, pinned, group = rows[1], rows[2], rows[3]

  -- test_hud_selected_row_shows_quest_log_highlight_in_preset_colour
  assertNativeArt(selected.selectionFill, SELECTED_ART, "HUD selected")
  assert(selected.selectionFill.shown == true, "HUD selected: art shown while selected")
  assert(rgbMatches(selected.selectionFill.vertexColor, Theme.COLORS.bg_contact_selected), "HUD selected: tinted with the preset selection colour")

  -- test_hud_rows_have_no_accent_bar_and_no_flat_fill
  for index, row in ipairs(rows) do
    assert(row.accentBar == nil or row.accentBar.shown ~= true, "HUD row " .. index .. ": no accent bar")
    assert(isClear(row.bg), "HUD row " .. index .. ": base bg stays clear so the inset shows")
  end

  -- test_hud_hover_shows_quest_title_highlight
  assertNativeArt(pinned.hoverFill, PickerPopup.MENU_HIGHLIGHT, "HUD hover")
  pinned.mouseOver = true
  pinned.scripts.OnEnter(pinned)
  assert(pinned.hoverFill.shown == true, "HUD hover: art shown on hover")
  assert(isClear(pinned.bg), "HUD hover: pinned row gets no flat fill")

  -- test_hud_selection_is_subtle_and_hover_clearly_fainter
  -- In game the additive art at 0.8 / 0.4 washed rows out and made a hovered
  -- row look selected.
  local selectedAlpha = selected.selectionFill.vertexColor[4]
  local hoverAlpha = pinned.hoverFill:GetAlpha()
  assert(selectedAlpha <= 0.5, "HUD selected: art stays subtle so row text reads, got " .. selectedAlpha)
  assert(hoverAlpha <= selectedAlpha / 2, "HUD hover: at most half the selection strength, got " .. hoverAlpha .. " vs " .. selectedAlpha)
  pinned.mouseOver = false
  pinned.scripts.OnLeave(pinned)
  assert(pinned.hoverFill.shown == false, "HUD hover: art hidden after leave")

  -- test_hud_hover_on_selected_row_keeps_selection_art_only
  selected.mouseOver = true
  selected.scripts.OnEnter(selected)
  assert(selected.selectionFill.shown == true, "HUD selected+hover: selection art stays")
  assert(selected.hoverFill.shown ~= true, "HUD selected+hover: hover art suppressed")
  selected.mouseOver = false
  selected.scripts.OnLeave(selected)

  -- test_hud_action_button_restore_keeps_hud_look
  pinned.mouseOver = true
  pinned.scripts.OnEnter(pinned)
  pinned.removeButton.scripts.OnEnter(pinned.removeButton)
  assert(isClear(pinned.bg), "HUD action hover: no flat fill")
  pinned.mouseOver = false
  pinned.scripts.OnLeave(pinned)
  pinned.removeButton.scripts.OnLeave(pinned.removeButton)
  assert(isClear(pinned.bg), "HUD action leave: no flat fill")
  assert(pinned.hoverFill.shown == false, "HUD action leave: hover art hidden")

  -- test_hud_group_row_gets_the_same_art
  rows = refresh(factory, parent, rows, ITEMS[3].conversationKey)
  assertNativeArt(group.selectionFill, SELECTED_ART, "HUD group selected")
  assert(group.selectionFill.shown == true, "HUD group: selection art shown")
  assert(isClear(group.bg), "HUD group: no muted flat fill")

  -- test_hud_deselect_hides_selection_art
  assert(selected.selectionFill.shown == false, "HUD deselect: art hidden on the old row")

  -- test_hud_pin_toggle_keeps_hud_look
  ITEMS[1].pinned = true
  rows = refresh(factory, parent, rows, ITEMS[1].conversationKey)
  assert(isClear(selected.bg), "HUD pin: pinned selected row has no flat fill")
  assertNativeArt(selected.selectionFill, SELECTED_ART, "HUD pin")
  ITEMS[1].pinned = false
  rows = refresh(factory, parent, rows, ITEMS[1].conversationKey)
  assert(isClear(selected.bg), "HUD unpin: row has no flat fill")

  -- test_hud_preset_change_retints_selection_art
  Theme.SetPreset("plumber_warm")
  refresh(factory, parent, rows, ITEMS[1].conversationKey)
  assert(rgbMatches(selected.selectionFill.vertexColor, Theme.COLORS.bg_contact_selected), "HUD preset change: selection art re-tinted")
  assertNativeArt(selected.selectionFill, SELECTED_ART, "HUD preset change")

  Hud.Configure("off")
  Theme.SetPreset(previousPreset)
  print("PASS: test_row_hover_overlay_hud")
end
