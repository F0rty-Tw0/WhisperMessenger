local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  local savedGetUnitSpeed = _G.GetUnitSpeed
  local savedIsMouselooking = _G.IsMouselooking
  local savedIsMouseButtonDown = _G.IsMouseButtonDown
  local movementSpeed = 0
  local isMouselooking = false
  local pressedButtons = {}

  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.GetUnitSpeed = function(unit)
    if unit == "player" then
      return movementSpeed
    end

    return 0
  end
  _G.IsMouselooking = function()
    return isMouselooking
  end
  _G.IsMouseButtonDown = function(button)
    if button == nil then
      for _, isPressed in pairs(pressedButtons) do
        if isPressed then
          return true
        end
      end

      return false
    end

    return pressedButtons[button] == true
  end

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
  assert(window.frame.alpha == Theme.WINDOW_IDLE_ALPHA, "expected shown window to start fully opaque")

  window.frame.scripts.OnUpdate(window.frame, Theme.WINDOW_ALPHA_UPDATE_INTERVAL)
  assert(window.frame.alpha == Theme.WINDOW_IDLE_ALPHA, "expected idle unfocused window to stay fully opaque")

  movementSpeed = 7
  window.frame.scripts.OnUpdate(window.frame, Theme.WINDOW_ALPHA_UPDATE_INTERVAL)
  assert(
    window.frame.alpha == Theme.WINDOW_EXTERNAL_ACTIVITY_ALPHA,
    "expected player movement outside the window to dim it"
  )

  movementSpeed = 0
  window.frame.scripts.OnUpdate(window.frame, Theme.WINDOW_ALPHA_UPDATE_INTERVAL)
  assert(window.frame.alpha == Theme.WINDOW_IDLE_ALPHA, "expected opacity to restore after movement stops")

  isMouselooking = true
  window.frame.scripts.OnUpdate(window.frame, Theme.WINDOW_ALPHA_UPDATE_INTERVAL)
  assert(window.frame.alpha == Theme.WINDOW_EXTERNAL_ACTIVITY_ALPHA, "expected camera look activity to dim the window")

  isMouselooking = false
  window.frame.scripts.OnUpdate(window.frame, Theme.WINDOW_ALPHA_UPDATE_INTERVAL)
  assert(window.frame.alpha == Theme.WINDOW_IDLE_ALPHA, "expected opacity to restore after camera activity stops")

  pressedButtons.LeftButton = true
  window.frame.scripts.OnUpdate(window.frame, Theme.WINDOW_ALPHA_UPDATE_INTERVAL)
  assert(
    window.frame.alpha == Theme.WINDOW_EXTERNAL_ACTIVITY_ALPHA,
    "expected outside mouse interaction to dim the window"
  )

  window.frame.mouseOver = true
  window.frame.scripts.OnEnter(window.frame)
  assert(window.frame.alpha == Theme.WINDOW_IDLE_ALPHA, "expected hover to restore full opacity")

  window.frame.mouseOver = false
  pressedButtons.LeftButton = false
  window.frame.scripts.OnLeave(window.frame)
  assert(
    window.frame.alpha == Theme.WINDOW_IDLE_ALPHA,
    "expected leaving the window without activity to keep it opaque"
  )

  window.composer.input:SetFocus()
  assert(window.frame.alpha == Theme.WINDOW_IDLE_ALPHA, "expected focused input to keep the window fully opaque")

  movementSpeed = 7
  window.frame.scripts.OnUpdate(window.frame, Theme.WINDOW_ALPHA_UPDATE_INTERVAL)
  assert(window.frame.alpha == Theme.WINDOW_IDLE_ALPHA, "expected focus to override outside activity dimming")

  movementSpeed = 0
  window.composer.input:ClearFocus()
  window.frame.scripts.OnUpdate(window.frame, Theme.WINDOW_ALPHA_UPDATE_INTERVAL)
  assert(
    window.frame.alpha == Theme.WINDOW_IDLE_ALPHA,
    "expected opacity to return to normal after focus and outside activity end"
  )

  _G.UIParent = savedUIParent
  _G.GetUnitSpeed = savedGetUnitSpeed
  _G.IsMouselooking = savedIsMouselooking
  _G.IsMouseButtonDown = savedIsMouseButtonDown
end
