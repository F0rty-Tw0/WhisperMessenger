local FakeUI = require("tests.helpers.fake_ui")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

-- The button riding the compact window hides its cards; landing home brings
-- another addon's card back. ToggleIcon wires the ride to the preview.

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:Show()
  local icon = ToggleIcon.Create(factory, { parent = parent })
  icon.frame:Show()
  local target = { region = factory.CreateFrame("Frame", nil, parent), relativePoint = "CENTER", x = 0, y = 0, scale = 2, level = 3000 }
  return icon, target
end

local function entry()
  return {
    sender = "Crafter",
    text = "Needs Plate Belt",
    onClick = function() end,
    onDismiss = function() end,
    onShown = function() end,
  }
end

return function()
  local function test_riding_hides_the_external_card_and_landing_home_brings_it_back()
    local icon, target = build()
    icon.setExternalPreview(entry())
    assert(icon.isExternalPreviewShown(), "shown at home")
    icon.rideTo(target)
    assert(icon.isRiding(), "the button left for the window")
    assert(not icon.previewFrame:IsVisible() and not icon.isExternalPreviewShown(), "hidden while riding")
    icon.rideHome()
    assert(icon.previewFrame:IsVisible() and icon.isExternalPreviewShown(), "back once the button is home")
  end

  local function test_a_card_set_while_riding_waits_for_home()
    local icon, target = build()
    icon.rideTo(target)
    icon.setExternalPreview(entry())
    assert(not icon.isExternalPreviewShown(), "a card set while riding stays hidden")
    icon.rideHome()
    assert(icon.isExternalPreviewShown(), "and shows at home")
  end

  test_riding_hides_the_external_card_and_landing_home_brings_it_back()
  test_a_card_set_while_riding_waits_for_home()
end
