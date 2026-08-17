local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")
local Trace = require("WhisperMessenger.Core.Trace")

return function()
  local sent = {}
  local traceLines = {}
  local savedPrint = _G.print
  local selectedContact = {
    conversationKey = "me::WOW::arthas-area52",
    displayName = "Arthas-Area52",
    channel = "WOW",
  }

  rawset(_G, "print", function(_, line)
    table.insert(traceLines, line)
  end)
  Trace.enable()

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
    return payload.text ~= "rejected draft"
  end)

  composer.input:SetText("live api text")
  composer.sendButton.scripts.OnClick()

  assert(sent[1] ~= nil, "expected send button to submit text from EditBox:GetText()")
  assert(sent[1].text == "live api text")
  assert(composer.input:GetText() == "", "expected accepted draft to clear")

  composer.input:SetText("rejected draft")
  composer.input.scripts.OnEnterPressed(composer.input)

  assert(sent[2] ~= nil, "expected Enter to submit text from EditBox:GetText()")
  assert(sent[2].text == "rejected draft")
  assert(composer.input:GetText() == "rejected draft", "expected rejected draft to remain")

  Trace.disable()
  rawset(_G, "print", savedPrint)

  assert(traceLines[1] == "Composer: before-callback channel=WOW")
  assert(traceLines[2] == "Composer: callback-result type=boolean value=true")
  assert(traceLines[3] == "Composer: post-clear empty=true")
  assert(traceLines[4] == "Composer: before-callback channel=WOW")
  assert(traceLines[5] == "Composer: callback-result type=boolean value=false")
  local traceOutput = table.concat(traceLines, "\n")
  assert(not string.find(traceOutput, "live api text", 1, true), "trace must not log successful message text")
  assert(not string.find(traceOutput, "rejected draft", 1, true), "trace must not log rejected message text")
end
