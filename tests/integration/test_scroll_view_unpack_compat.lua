local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  local savedUnpack = _G.unpack
  local savedTableUnpack = table.unpack

  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.unpack = function(values)
    return savedTableUnpack(values)
  end
  table.unpack = nil

  local ok, window = pcall(MessengerWindow.Create, factory, {
    title = "WhisperMessenger",
    contacts = {},
  })

  table.unpack = savedTableUnpack
  _G.unpack = savedUnpack
  _G.UIParent = savedUIParent

  assert(ok == true, tostring(window))
  assert(window ~= nil and window.frame ~= nil, "expected window creation to succeed when only global unpack exists")
end
