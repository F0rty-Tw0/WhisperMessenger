-- Under the Native WoW HUD the Message Retention row is the game's dropdown
-- (one radio per choice), built from the same choice list as the modern one.
local FakeUI = require("tests.helpers.fake_ui")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Retention = require("WhisperMessenger.Model.Retention")
local RetentionRow = require("WhisperMessenger.UI.MessengerWindow.GeneralSettings.RetentionRow")

local DROPDOWN_TEMPLATE = "WowStyle1DropdownTemplate"

-- Just the DropdownButton methods production calls: SetupMenu, GenerateMenu.
local function dropdownFactory()
  local base = FakeUI.NewFactory()
  return {
    CreateFrame = function(frameType, name, parent, template)
      local frame = base.CreateFrame(frameType, name, parent, template)
      if template == DROPDOWN_TEMPLATE then
        function frame:SetupMenu(generator)
          self.generator = generator
        end
        function frame:GenerateMenu() end
      end
      return frame
    end,
  }
end

-- Runs the menu generator; returns the radios.
local function openMenu(dropdown)
  local radios = {}
  local root = {
    CreateRadio = function(_self, text, isSelected, setSelected, data)
      radios[#radios + 1] = { text = text, isSelected = isSelected, setSelected = setSelected, data = data }
    end,
  }
  dropdown.button.generator(dropdown.button, root)
  return radios
end

local function radioNamed(radios, text)
  for _, radio in ipairs(radios) do
    if radio.text == text then
      return radio
    end
  end
  return nil
end

return function()
  local factory = dropdownFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  Hud.Configure("classic")
  local dropdown = RetentionRow.Create(factory, parent, {
    language = "enUS",
    initial = 48 * 3600,
    onChange = function(seconds)
      changes[#changes + 1] = seconds
    end,
  })
  Hud.Configure("off")

  -- test_hud_retention_uses_the_game_dropdown
  assert(dropdown.button.template == DROPDOWN_TEMPLATE, "HUD: retention uses the game's dropdown, got " .. tostring(dropdown.button.template))

  -- test_hud_custom_value_is_the_checked_radio
  local radios = openMenu(dropdown)
  local custom = radioNamed(radios, "48 hours")
  assert(custom ~= nil and custom.isSelected(custom.data), "saved 48h is listed and checked")

  -- test_hud_pick_writes_seconds_and_drops_the_custom_radio
  local forever = radioNamed(radios, "Forever")
  forever.setSelected(forever.data)
  assert(changes[1] == Retention.FOREVER_SECONDS, "Forever radio writes FOREVER_SECONDS, got " .. tostring(changes[1]))
  assert(radioNamed(openMenu(dropdown), "48 hours") == nil, "custom radio leaves once another choice is picked")
end
