rawset(_G, "time", os.time)
_G.date = os.date

local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local MODERN_PRESETS = { "wow_default", "elvui_dark", "plumber_warm", "jade_dark", "wow_native" }
-- Assumed timestamp line: top 2px below the row top, ~10px tall.
local TIME_BOTTOM = 12

local function item(key, pinned, unread)
  return {
    conversationKey = "me::WOW::" .. key,
    displayName = "Contact" .. key,
    lastPreview = "hi",
    unreadCount = unread or 0,
    lastActivityAt = 100,
    channel = "WOW",
    pinned = pinned,
  }
end

local function sameRgb(a, b)
  return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)
  local options = { onSelect = function() end, onPin = function() end, onRemove = function() end }
  local function bind(it)
    return RowView.bindRow(factory, parent, nil, 1, it, options)
  end

  Theme.SetPreset("wow_default")
  local layout = Theme.LAYOUT
  local size = layout.CONTACT_ACTION_SIZE
  local row = bind(item("a", false))
  local pinPoint = row.pinButton.point
  local gap = -pinPoint[5]

  -- test_modern_column_fits_row_with_even_gaps
  assert(gap >= 2, "column gap is at least 2px")
  local columnBottom = TIME_BOTTOM + gap + size + gap + size
  assert(columnBottom <= layout.CONTACT_ROW_HEIGHT - 2, "time + pin + remove fit in the row: " .. columnBottom)

  -- test_modern_pin_sits_under_timestamp_and_remove_under_pin
  assert(pinPoint[1] == "TOPRIGHT" and pinPoint[2] == row.timeLabel and pinPoint[3] == "BOTTOMRIGHT", "pin under the timestamp")
  local removePoint = row.removeButton.point
  assert(removePoint[1] == "TOPRIGHT" and removePoint[2] == row.pinButton and removePoint[3] == "BOTTOMRIGHT", "remove under the pin")
  assert(removePoint[4] == 0 and removePoint[5] == -gap, "remove right-aligned with the pin, one gap below")
  assert(pinPoint[4] == 1, "pin glyph right edge lines up with the timestamp text")

  -- test_modern_hover_keeps_timestamp
  row.timeLabel:Show() -- fake UI starts widgets hidden; WoW shows them
  row.mouseOver = true
  row.scripts.OnEnter(row)
  assert(row.timeLabel:IsShown() == true, "modern: timestamp stays while actions show")
  assert(row.pinButton:IsShown() and row.removeButton:IsShown(), "hover shows pin and remove")
  row.mouseOver = false
  row.scripts.OnLeave(row)

  -- test_modern_pinned_marker_occupies_pin_slot
  local pinned = bind(item("b", true))
  local marker = pinned.pinnedMarker
  assert(marker ~= nil and marker.shown == true, "pinned row at rest shows the marker")
  assert(marker.point[1] == "CENTER" and marker.point[2] == pinned.pinButton, "marker sits in the pin slot")
  assert(marker.width == pinned.pinButton.icon.width, "marker matches the pin glyph size")
  assert(pinned.pinButton:IsShown() == false, "no Unpin button at rest")
  pinned.mouseOver = true
  pinned.scripts.OnEnter(pinned)
  assert(marker.shown == false and pinned.pinButton:IsShown(), "hover swaps the marker for the Unpin button")
  assert(pinned.pinButton.icon.texturePath == Theme.TEXTURES.unpin_icon, "hover shows unpin glyph")
  pinned.mouseOver = false
  pinned.scripts.OnLeave(pinned)
  assert(marker.shown == true and pinned.pinButton:IsShown() == false, "leave restores the marker")

  -- test_name_not_squeezed_by_marker
  assert(pinned.title.width == row.title.width, "marker no longer steals width from the name")

  -- test_unread_badge_hides_marker
  local unread = bind(item("c", true, 3))
  assert(unread.pinnedMarker == nil or unread.pinnedMarker.shown ~= true, "unread badge owns the corner; marker hidden")

  -- test_modern_remove_uses_trash_icon
  assert(Theme.TEXTURES.trash_icon == "Interface\\AddOns\\WhisperMessenger\\Media\\remove.png", "trash icon registered")
  assert(row.removeButton.icon.texturePath == Theme.TEXTURES.trash_icon, "modern remove uses the trash glyph")
  row.removeButton.scripts.OnEnter(row.removeButton)
  assert(sameRgb(row.removeButton.icon.vertexColor, Theme.COLORS.action_remove_hover), "trash turns danger red on hover")
  row.removeButton.scripts.OnLeave(row.removeButton)
  assert(sameRgb(row.removeButton.icon.vertexColor, Theme.COLORS.action_icon), "trash neutral at rest")

  -- test_modern_pinned_bg_is_subtle_accent_tint
  for _, key in ipairs(MODERN_PRESETS) do
    Theme.SetPreset(key)
    local c = Theme.COLORS
    local tint = c.bg_contact_pinned
    assert(sameRgb(tint, c.accent), key .. ": pinned tint uses the accent colour")
    assert(tint[4] == 0.05, key .. ": pinned tint alpha 0.05")
    assert(tint[4] < c.bg_contact_selected[4], key .. ": pinned stays below the selected tint")
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_row_action_column")
end
