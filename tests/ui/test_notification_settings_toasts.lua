local FakeUI = require("tests.helpers.fake_ui")
local NotificationSettings = require("WhisperMessenger.UI.MessengerWindow.NotificationSettings")
local FindUI = require("tests.helpers.find_ui")

local TOGGLE = "Show pop-up cards"
local POSITION = "Pop-up card position"

local function build(config)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = NotificationSettings.Create(factory, parent, config or {}, {
    onChange = function(key, value)
      changes[key] = value
    end,
  })
  return result.frame, changes
end

local function cornerButton(frame, label)
  for _, button in ipairs(FindUI.selectorButtons(frame, POSITION)) do
    if FindUI.text(button, label) then
      return button
    end
  end
  error("no corner button '" .. label .. "'")
end

return function()
  -- test_cards_toggle_defaults_off
  do
    local frame = build()
    assert(FindUI.isToggleOn(FindUI.toggle(frame, TOGGLE)) == false, "pop-up cards start off")
  end

  -- test_clicking_cards_toggle_saves_on
  do
    local frame, changes = build()
    FindUI.click(FindUI.toggle(frame, TOGGLE))
    assert(changes.showWhisperToasts == true, "click turns pop-up cards on")
  end

  -- test_position_offers_the_four_corners
  do
    local frame = build({ showWhisperToasts = true })
    for _, label in ipairs({ "Top left", "Top right", "Bottom left", "Bottom right" }) do
      cornerButton(frame, label)
    end
  end

  -- test_picking_a_corner_saves_it
  do
    local frame, changes = build({ showWhisperToasts = true })
    FindUI.click(cornerButton(frame, "Bottom left"))
    assert(changes.whisperToastCorner == "BOTTOMLEFT", "corner saved, got " .. tostring(changes.whisperToastCorner))
  end

  -- test_position_is_disabled_while_cards_are_off
  do
    local frame = build()
    assert(FindUI.disabledCover(FindUI.byLabel(frame, POSITION)) ~= nil, "position is greyed out while cards are off")
  end

  -- test_turning_cards_on_enables_position
  do
    local frame = build()
    FindUI.click(FindUI.toggle(frame, TOGGLE))
    assert(FindUI.disabledCover(FindUI.byLabel(frame, POSITION)) == nil, "position is usable once cards are on")
  end

  -- test_reset_turns_cards_off_and_disables_position
  do
    local frame, changes = build({ showWhisperToasts = true, whisperToastCorner = "BOTTOMLEFT" })
    FindUI.click(FindUI.byLabel(frame, "Reset to Defaults"))
    assert(changes.showWhisperToasts == false, "reset turns cards off")
    assert(changes.whisperToastCorner == "TOPRIGHT", "reset puts cards back top-right")
    assert(FindUI.disabledCover(FindUI.byLabel(frame, POSITION)) ~= nil, "position greys out again after reset")
  end
end
