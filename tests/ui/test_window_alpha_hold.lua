local WindowAlpha = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowAlpha")
local AlphaController = require("WhisperMessenger.UI.MessengerWindow.AlphaController")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  -- test_held_alpha_ignores_the_ticker_and_focus_changes
  do
    local factory = FakeUI.NewFactory()
    local frame = factory.CreateFrame("Frame", nil, nil)
    local input = factory.CreateFrame("EditBox", nil, nil)
    local windowAlpha = WindowAlpha.Create({ alphaController = AlphaController, frame = frame, composerInput = input })
    windowAlpha.setHeld(true)
    frame:SetAlpha(0)
    windowAlpha.refreshWindowAlpha(true)
    assert(frame:GetAlpha() == 0, "the ticker waits")
    input.scripts.OnEditFocusGained(input)
    assert(frame:GetAlpha() == 0, "focus waits too")
    windowAlpha.setHeld(false)
    windowAlpha.refreshWindowAlpha(true)
    assert(frame:GetAlpha() == 1, "released")
  end
end
