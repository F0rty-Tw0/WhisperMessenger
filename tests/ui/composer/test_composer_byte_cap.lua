local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  -- test_input_accepts_a_full_255_byte_whisper
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "parent", nil)
    parent:SetSize(600, 50)
    local contact = { conversationKey = "me::WOW::arthas", displayName = "Arthas", channel = "WOW" }
    local composer = Composer.Create(factory, parent, contact, function() end)

    composer.input:Insert(string.rep("a", 300))

    local length = #composer.input:GetText()
    assert(length == 255, "input should hold a full 255-byte whisper, got " .. tostring(length))
  end
end
