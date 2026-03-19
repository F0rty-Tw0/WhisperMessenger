local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

  local window = MessengerWindow.Create(factory, {
    title = "WhisperMessenger",
    contacts = {},
  })

  assert(type(window.frame.scripts.OnDragStart) == "function")
  assert(type(window.frame.scripts.OnDragStop) == "function")

  window.frame.scripts.OnDragStart(window.frame)
  assert(window.frame.startedMoving == true)

  window.frame.scripts.OnDragStop(window.frame)
  assert(window.frame.stoppedMoving == true)

  _G.UIParent = savedUIParent
end
