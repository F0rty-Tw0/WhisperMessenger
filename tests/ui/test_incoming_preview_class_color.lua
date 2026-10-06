local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local IncomingPreview = require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")

local MAGE = { 0.25, 0.78, 0.92 }

local function assertColor(fontString, expected, label)
  local actual = { fontString:GetTextColor() }
  local expectedAlpha = expected[4] or 1
  local matches = math.abs(actual[4] - expectedAlpha) < 0.001
  for i = 1, 3 do
    matches = matches and math.abs(actual[i] - expected[i]) < 0.001
  end
  assert(matches, label .. ": got " .. table.concat(actual, ", "))
end

return function()
  local previousClassColors = _G.RAID_CLASS_COLORS
  _G.RAID_CLASS_COLORS = { MAGE = { r = MAGE[1], g = MAGE[2], b = MAGE[3] } }

  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(48, 48)
  local preview = IncomingPreview.Create(factory, parent, {})
  local primary = Theme.COLORS.text_primary

  -- test_flag_on_colours_sender_by_class

  do
    DisplayName.Configure({ classColorSenderNames = true })
    preview.setIncomingPreview("Jaina", "hi", "MAGE")
    assertColor(preview.senderLabel, MAGE, "the preview sender takes the mage class colour")
  end

  -- test_flag_on_unknown_class_keeps_plain_colour

  do
    DisplayName.Configure({ classColorSenderNames = true })
    preview.setIncomingPreview("Mike#1234", "hi", nil)
    assertColor(preview.senderLabel, primary, "a sender with no class keeps text_primary")
  end

  -- test_flag_off_keeps_plain_colour

  do
    DisplayName.Configure({ classColorSenderNames = false })
    preview.setIncomingPreview("Jaina", "hi", "MAGE")
    assertColor(preview.senderLabel, primary, "with the option off the sender keeps text_primary")
  end

  -- test_theme_change_keeps_class_colour

  do
    DisplayName.Configure({ classColorSenderNames = true })
    preview.setIncomingPreview("Jaina", "hi", "MAGE")
    preview.applyTheme(Theme)
    assertColor(preview.senderLabel, MAGE, "a theme change keeps the shown sender's class colour")
  end

  DisplayName.Configure({ classColorSenderNames = true })
  _G.RAID_CLASS_COLORS = previousClassColors
end
