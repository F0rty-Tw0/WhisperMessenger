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
  PickerPopup.SetEscapeFrameShownHandler(nil)
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

  -- test_shown_popup_is_reported_once
  -- The messenger window leaves the ESC list while its popup is open, so
  -- ESC closes only the popup.
  withPopup(function(popup)
    local reported = {}
    PickerPopup.SetEscapeFrameShownHandler(function(shown)
      table.insert(reported, shown)
    end)
    PickerPopup.RegisterEscape(NAME, popup)
    PickerPopup.RegisterEscape(NAME, popup)
    popup:Show()
    assert(#reported == 1 and reported[1] == popup, "an opened popup must be reported once")
  end)
end
