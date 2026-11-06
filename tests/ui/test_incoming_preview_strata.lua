local FakeUI = require("tests.helpers.fake_ui")
local IncomingPreview = require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")
local Theme = require("WhisperMessenger.UI.Theme")

return function()
  -- test_the_preview_keeps_its_strata_when_the_button_changes_its_own
  do
    local factory = FakeUI.NewFactory()
    local button = factory.CreateFrame("Button", "Fab", nil)
    local preview = IncomingPreview.Create(factory, button, { theme = Theme })
    assert(preview.frame:GetFrameStrata() == "HIGH", "above action bars")
    assert(preview.frame.fixedFrameStrata == true, "a riding button going back with the window leaves it up")
  end
end
