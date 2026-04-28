local FakeUI = require("tests.helpers.fake_ui")
local IncomingPreview = require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(48, 48)

  local dismissed = false
  local preview = IncomingPreview.Create(factory, parent, {
    onDismissPreview = function()
      dismissed = true
    end,
  })

  assert(preview.frame ~= nil, "preview frame should exist")
  assert(preview.frame.shown == false, "preview should start hidden")

  preview.setIncomingPreview("Jaina-Proudmoore", "Need assistance?", "MAGE")
  assert(preview.frame.shown == true, "preview should show after setting content")
  assert(preview.senderLabel.text == "Jaina-Proudmoore", "sender label should render sender name")
  assert(preview.messageLabel.text == "Need assistance?", "message label should render message text")

  local onClick = preview.dismissButton:GetScript("OnClick")
  assert(type(onClick) == "function", "dismiss button should expose OnClick handler")
  onClick(preview.dismissButton)

  assert(dismissed == true, "dismiss callback should fire on dismiss button click")
  assert(preview.frame.shown == false, "preview should hide after dismiss")
  assert(preview.senderLabel.text == "", "sender label should clear after dismiss")
  assert(preview.messageLabel.text == "", "message label should clear after dismiss")
end
