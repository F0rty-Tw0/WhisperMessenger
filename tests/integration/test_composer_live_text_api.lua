local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local sent = {}
  local selectedContact = {
    conversationKey = "me::WOW::arthas-area52",
    displayName = "Arthas-Area52",
    channel = "WOW",
  }

  local baseFactory = FakeUI.NewFactory()
  local factory = {}
  factory.CreateFrame = function(frameType, name, parent, template)
    local frame = baseFactory.CreateFrame(frameType, name, parent, template)
    if frameType == "EditBox" then
      local originalSetText = frame.SetText
      rawset(frame, "SetText", function(self, value)
        originalSetText(self, value)
        self._textValue = value
        self.text = nil
      end)
      rawset(frame, "GetText", function(self)
        return self._textValue
      end)
    end
    return frame
  end

  local parent = factory.CreateFrame("Frame", "ComposerParent", nil)
  parent:SetSize(600, 200)

  local composer = Composer.Create(factory, parent, selectedContact, function(payload)
    table.insert(sent, payload)
  end)

  composer.input:SetText("live api text")
  composer.sendButton.scripts.OnClick()

  assert(sent[1] ~= nil, "expected send button to submit text from EditBox:GetText()")
  assert(sent[1].text == "live api text")
end
