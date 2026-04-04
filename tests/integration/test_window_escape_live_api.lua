local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local savedUISpecialFrames = _G.UISpecialFrames
  _G.UISpecialFrames = {}

  local baseFactory = FakeUI.NewFactory()
  local factory = {}
  factory.CreateFrame = function(frameType, name, parent, template)
    local frame = baseFactory.CreateFrame(frameType, name, parent, template)
    local publicName = frame.name
    frame.name = nil
    rawset(frame, "GetName", function(self)
      return publicName
    end)
    return frame
  end

  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

  local window = MessengerWindow.Create(factory, {
    title = "WhisperMessenger",
    contacts = {},
  })

  assert(window.frame.GetName ~= nil, "expected window to expose GetName()")
  assert(_G.UISpecialFrames[1] == "WhisperMessengerWindow", "expected UISpecialFrames registration to use GetName()")

  _G.UIParent = savedUIParent
  _G.UISpecialFrames = savedUISpecialFrames
end
