local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ContactsList = require("WhisperMessenger.UI.ContactsList")

local function colorsMatch(a, b)
  return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local function item(key, pinned)
  return {
    conversationKey = "me::WOW::" .. key,
    displayName = "Averyveryverylongcontactname" .. key,
    lastPreview = "hi",
    unreadCount = 0,
    lastActivityAt = 100,
    channel = "WOW",
    pinned = pinned,
  }
end

local function render(items)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)
  return ContactsList.Refresh(factory, parent, {}, items, {
    visibleCount = #items,
    onSelect = function() end,
    onPin = function() end,
    onRemove = function() end,
  })
end

local function hover(row, over)
  row.mouseOver = over
  row.scripts[over and "OnEnter" or "OnLeave"](row)
end

return function()
  local previousPreset = Theme.GetPreset()
  assert(Theme.TEXTURES.pin_icon == "Interface\\AddOns\\WhisperMessenger\\Media\\pin.png", "pin icon path in Theme.TEXTURES")
  assert(Theme.TEXTURES.unpin_icon == "Interface\\AddOns\\WhisperMessenger\\Media\\unpin.png", "unpin icon path in Theme.TEXTURES")
  assert(Theme.TEXTURES.pinned_marker == "Interface\\AddOns\\WhisperMessenger\\Media\\pinned.png", "pinned marker path in Theme.TEXTURES")

  -- test_modern_pinned_row_shows_marker_not_chevron
  Theme.SetPreset("wow_default")
  local rows = render({ item("a", true), item("b", false) })
  local pinnedRow, plainRow = rows[1], rows[2]
  local marker = pinnedRow.pinnedMarker
  assert(marker ~= nil and marker.shown == true, "modern: pinned row shows the pinned marker")
  assert(marker.texturePath == Theme.TEXTURES.pinned_marker, "modern: marker uses pinned.png")
  assert(marker.width >= 10 and marker.width <= 12, "modern: marker is 10-12px")
  pinnedRow.timeLabel:Show() -- fake UI starts widgets hidden
  assert(colorsMatch(marker.vertexColor, Theme.COLORS.text_secondary), "modern: marker in secondary text colour")
  local markerPoint = marker.point
  assert(markerPoint[1] == "CENTER" and markerPoint[2] == pinnedRow.pinButton, "marker sits in the pin slot under the timestamp")
  assert(pinnedRow.pinButton.shown == false, "modern: no chevron / pin action at rest")

  -- test_pin_glyphs_are_pixel_snapped: integer size, whole-pixel centre offset
  local slot = pinnedRow.pinButton.width
  for _, glyph in ipairs({ marker, pinnedRow.pinButton.icon, pinnedRow.removeButton.icon }) do
    assert(glyph.width == math.floor(glyph.width) and glyph.width == glyph.height, "glyph size is an integer square")
    local offset = (slot - glyph.width) / 2
    assert(offset == math.floor(offset), "glyph centred on a whole-pixel offset, got " .. tostring(offset))
  end
  assert(plainRow.pinnedMarker == nil or plainRow.pinnedMarker.shown ~= true, "unpinned rows have no marker")

  -- test_modern_hover_swaps_marker_for_actions
  hover(pinnedRow, true)
  assert(pinnedRow.pinButton.shown == true and pinnedRow.removeButton.shown == true, "hover shows the actions")
  assert(pinnedRow.timeLabel.shown == true and marker.shown == false, "hover keeps the timestamp, hides the marker")
  assert(pinnedRow.pinButton.icon.texturePath == Theme.TEXTURES.unpin_icon, "pinned row action is Unpin (unpin.png)")
  assert(colorsMatch(pinnedRow.pinButton.icon.vertexColor, Theme.COLORS.action_icon), "unpin glyph is neutral, not yellow")
  hover(pinnedRow, false)
  assert(pinnedRow.timeLabel.shown == true and marker.shown == true, "leave restores timestamp and marker")

  hover(plainRow, true)
  assert(plainRow.pinButton.icon.texturePath == Theme.TEXTURES.pin_icon, "unpinned row action is Pin to top (pin.png)")
  hover(plainRow, false)

  -- test_name_not_squeezed_by_marker
  assert(pinnedRow.title.width == plainRow.title.width, "marker lives under the timestamp, not beside the name")

  -- test_azeroth_uses_the_pushpin_marker
  Theme.SetPreset("wow_native")
  rows = render({ item("c", true) })
  assert(rows[1].pinButton.shown == false, "azeroth: no static pin button at rest")
  assert(rows[1].pinnedMarker ~= nil and rows[1].pinnedMarker.shown == true, "azeroth: pinned marker like every preset")

  Theme.SetPreset(previousPreset)
  print("PASS: test_pin_icons")
end
