local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon.ToggleIcon")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  -- test_widget_is_clamped_to_screen
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    parent:SetSize(800, 600)

    local icon = ToggleIcon.Create(factory, { parent = parent })

    assert(icon.frame.clamped == true, "widget frame must be clamped to the screen")
  end
end
