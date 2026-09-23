local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local FindUI = require("tests.helpers.find_ui")

-- Vertical offset of the last SetPoint for `anchor` (WoW replaces per anchor).
local function pointY(region, anchor)
  local y = nil
  for _, pt in ipairs(region.points or {}) do
    if pt[1] == anchor then
      y = pt[5]
    end
  end
  return y
end

local function build()
  local factory = FakeUI.NewFactory()
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  uiParent:SetSize(920, 580)
  local frame = factory.CreateFrame("Frame", "MainFrame", uiParent)
  frame:SetSize(920, 580)
  local layout = LayoutBuilder.Build(factory, frame, { width = 920, height = 580 }, {})
  LayoutBuilder.Relayout(layout, 920, 580)
  return layout
end

local function searchIcon(layout)
  return FindUI.find(layout.contactsSearchFrame, function(node)
    return node.texturePath == "Interface\\Common\\UI-Searchbox-Icon"
  end)
end

-- First fill texture of the rounded background (the field's first texture).
local function searchFill(layout)
  return FindUI.ofType(layout.contactsSearchFrame, "Texture")[1]
end

local function pointX(region, anchor)
  local x = nil
  for _, pt in ipairs(region.points or {}) do
    if pt[1] == anchor then
      x = pt[4]
    end
  end
  return x
end

-- Gap in px between the search field's bottom edge and the list viewport top
-- (both measured from the contacts pane top, downward positive).
local function searchGap(layout)
  local searchTop = -pointY(layout.contactsSearchFrame, "TOPLEFT")
  local searchBottom = searchTop + layout.contactsSearchFrame.height
  local listTop = -pointY(layout.contactsView.scrollFrame, "TOPLEFT")
  return listTop - searchBottom
end

return function()
  local previousPreset = Theme.GetPreset()

  -- test_modern_first_row_sits_below_search_with_gap
  for _, key in ipairs(Theme.ListPresets()) do
    Theme.SetPreset(key)
    local layout = build()
    local gap = searchGap(layout)
    assert(gap >= 6 and gap <= 8, key .. ": expected a 6-8px gap between search and first row, got " .. tostring(gap))
    assert(pointY(layout.contactsSearchFrame, "TOPLEFT") < 0, key .. ": search field inset from the pane top")
    -- Side margins: 4px each side, and the magnifier lines up with the row
    -- icons (row x-inset 2 + CONTACT_PADDING 6 = 8px from the pane edge).
    local insetX = pointX(layout.contactsSearchFrame, "TOPLEFT")
    assert(insetX == 4, key .. ": search field 4px from the pane's left edge, got " .. tostring(insetX))
    assert(layout.contactsSearchFrame.width == layout.contactsWidth - 8, key .. ": search field 4px from the right edge too")
    local iconX = insetX + pointX(searchIcon(layout), "LEFT")
    assert(iconX == 2 + Theme.LAYOUT.CONTACT_PADDING, key .. ": magnifier aligned with the row icons, got " .. tostring(iconX))
  end

  -- test_modern_search_is_soft_rounded_field
  do
    Theme.SetPreset("wow_default")
    local layout = build()
    assert(searchFill(layout).shown == true, "modern: rounded fill shown")
    assert(layout.contactsSearchBg == nil, "modern: no square fill")
    local icon = searchIcon(layout)
    assert(icon ~= nil and icon.shown == true, "modern: magnifier glyph shown")
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_contacts_search_layout")
end
