local RailAvatar = require("WhisperMessenger.UI.ContactsList.RailAvatar")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local UIHelpers = require("WhisperMessenger.UI.Helpers")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

-- The rail avatar is the row's own class icon (same art, helper, mask and
-- zoom as the full list), dimmed, with the contact's initials in white on
-- top of it.

local CLASS_ART = "Interface\\ICONS\\ClassIcon_MAGE"

-- A row's class icon exactly as RowElements builds it.
local function newRow(factory)
  local row = factory.CreateFrame("Button", nil, nil)
  local icon = UIHelpers.createCircularIcon(factory, row, Theme.LAYOUT.CONTACT_ICON_SIZE)
  row.classIconFrame = icon.frame
  row.classIcon = icon.texture
  row.classIcon:SetTexture(CLASS_ART)
  return row
end

local function isDimmed(color)
  return color[1] < 1 and color[1] > 0.3 and color[1] == color[2] and color[2] == color[3]
end

return function()
  local factory = FakeUI.NewFactory()

  -- test_avatar_keeps_the_class_art_dimmed
  do
    local row = newRow(factory)
    RailAvatar.update(row, { displayName = "Jaina-Proudmoore", classTag = "MAGE" })
    assert(row.classIcon.texturePath == CLASS_ART, "icon keeps its class art, got " .. tostring(row.classIcon.texturePath))
    assert(isDimmed(row.classIcon.vertexColor), "class art is dimmed so the initials read")
  end

  -- test_initials_sit_on_the_icon_frame_above_the_art
  do
    local row = newRow(factory)
    RailAvatar.update(row, { displayName = "Jaina-Proudmoore", classTag = "MAGE" })
    local label = row.railAvatar.label
    assert(label.parent == row.classIconFrame, "label lives on the icon frame, which draws above the row")
    assert(label.shown == true and label.text == "JA", "initials show, got " .. tostring(label.text))
  end

  -- test_initials_are_white_with_a_dark_edge
  do
    local row = newRow(factory)
    RailAvatar.update(row, { displayName = "Anna" })
    local label = row.railAvatar.label
    assert(label.textColor[1] == 1 and label.textColor[2] == 1 and label.textColor[3] == 1, "white initials")
    assert(label.shadowOffset ~= nil and label.shadowOffset[1] ~= 0, "dark edge keeps them readable on bright art")
  end

  -- test_nickname_wins_over_the_name
  do
    local row = newRow(factory)
    RailAvatar.update(row, { displayName = "Jaina", nickname = "Big Boss" })
    assert(row.railAvatar.label.text == "BB", "nickname initials, got " .. tostring(row.railAvatar.label.text))
  end

  -- test_battletag_numbers_shown_still_give_name_initials
  do
    DisplayName.Configure({ hideBattleTagNumbers = false })
    local row = newRow(factory)
    RailAvatar.update(row, { displayName = "Friend#1234" })
    assert(row.railAvatar.label.text == "FR", "number never becomes an initial, got " .. tostring(row.railAvatar.label.text))
    DisplayName.Configure({ hideBattleTagNumbers = true })
  end

  -- test_hide_drops_the_initials_and_undims_the_art
  do
    local row = newRow(factory)
    RailAvatar.update(row, { displayName = "Anna" })
    RailAvatar.hide(row)
    assert(row.railAvatar.label.shown == false, "initials hide")
    local c = row.classIcon.vertexColor
    assert(c[1] == 1 and c[2] == 1 and c[3] == 1, "art shows at full brightness again")
  end
end
