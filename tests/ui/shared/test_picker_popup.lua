local FakeUI = require("tests.helpers.fake_ui")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")

local NAME = "WhisperMessengerTestPicker"

-- Runs fn(popup) with a fresh UISpecialFrames and a popup frame under NAME.
local function withPopup(fn)
  local savedSpecial, savedPopup = _G.UISpecialFrames, _G[NAME]
  _G.UISpecialFrames = {}
  local popup = FakeUI.NewFactory().CreateFrame("Frame", NAME, nil)
  rawset(_G, NAME, popup)
  local ok, err = pcall(fn, popup)
  _G.UISpecialFrames = savedSpecial
  rawset(_G, NAME, savedPopup)
  assert(ok, err)
end

return function()
  -- test_register_escape_lists_the_popup_once
  withPopup(function()
    PickerPopup.RegisterEscape(NAME)
    PickerPopup.RegisterEscape(NAME)
    assert(#_G.UISpecialFrames == 1 and _G.UISpecialFrames[1] == NAME, "popup must close on ESC, listed once")
  end)

  -- test_hide_escape_frames_closes_an_open_popup
  -- The messenger's own ESC handler runs before UISpecialFrames, so it
  -- closes its popups itself.
  withPopup(function(popup)
    PickerPopup.RegisterEscape(NAME)
    popup:Show()
    assert(PickerPopup.HideEscapeFrames() == true, "closing an open popup must use up the ESC press")
    assert(not popup:IsShown(), "open popup must close")
  end)

  -- test_hide_escape_frames_without_open_popup_passes
  withPopup(function()
    PickerPopup.RegisterEscape(NAME)
    assert(PickerPopup.HideEscapeFrames() == false, "with no popup open the ESC press must go on")
  end)
end
