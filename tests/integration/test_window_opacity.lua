local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

  local window = MessengerWindow.Create(factory, {
    title = "WhisperMessenger",
    contacts = {},
  })

  assert(window.frame.scripts.OnUpdate ~= nil, "expected window opacity updater")
  assert(window.frame.scripts.OnEnter ~= nil, "expected window hover handler")
  assert(window.frame.scripts.OnLeave ~= nil, "expected window leave handler")
  assert(window.composer.input.scripts.OnEditFocusGained ~= nil, "expected focus gain opacity hook")
  assert(window.composer.input.scripts.OnEditFocusLost ~= nil, "expected focus loss opacity hook")

  window.frame:Show()
  assert(window.frame.alpha == Theme.WINDOW_ACTIVE_ALPHA, "expected shown window to start fully opaque")

  window.frame.scripts.OnUpdate(window.frame, Theme.WINDOW_ALPHA_UPDATE_INTERVAL)
  assert(window.frame.alpha == Theme.WINDOW_INACTIVE_ALPHA, "expected inactive window to dim after update polling")

  window.frame.mouseOver = true
  window.frame.scripts.OnEnter(window.frame)
  assert(window.frame.alpha == Theme.WINDOW_ACTIVE_ALPHA, "expected hover to restore full opacity")

  window.frame.mouseOver = false
  window.frame.scripts.OnLeave(window.frame)
  assert(window.frame.alpha == Theme.WINDOW_INACTIVE_ALPHA, "expected leaving the window to dim it when unfocused")

  window.frame.mouseOver = true
  window.composer.input:SetFocus()
  assert(window.frame.alpha == Theme.WINDOW_ACTIVE_ALPHA, "expected focused input to keep the window fully opaque")

  window.composer.input:ClearFocus()
  assert(window.frame.alpha == Theme.WINDOW_ACTIVE_ALPHA, "expected hover to keep the window opaque after input blur")

  window.frame.mouseOver = false
  window.frame.scripts.OnUpdate(window.frame, Theme.WINDOW_ALPHA_UPDATE_INTERVAL)
  assert(window.frame.alpha == Theme.WINDOW_INACTIVE_ALPHA, "expected outside actions to dim the window after focus and hover are gone")

  _G.UIParent = savedUIParent
end
