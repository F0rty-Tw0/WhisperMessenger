local Composer = require("WhisperMessenger.UI.Composer")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 50)

  local selectedContact = {
    conversationKey = "me::WOW::arthas-area52",
    displayName = "Arthas-Area52",
    channel = "WOW",
  }

  local composer = Composer.Create(factory, parent, selectedContact, function() end)
  local btn = composer.sendButton

  -- Send button should have a background texture
  assert(btn.sendBg ~= nil, "expected sendBg texture on button")

  -- Default state: accent color background
  local c = btn.sendBg.color
  assert(c ~= nil, "expected sendBg to have a color")
  local expected = Theme.COLORS.send_button
  assert(
    c[1] == expected[1] and c[2] == expected[2] and c[3] == expected[3],
    "expected send_button color, got: " .. tostring(c[1]) .. "," .. tostring(c[2]) .. "," .. tostring(c[3])
  )

  -- Hover: should switch to send_button_hover
  assert(btn.scripts.OnEnter ~= nil, "expected OnEnter script")
  btn.scripts.OnEnter(btn)
  local hc = btn.sendBg.color
  local hoverExpected = Theme.COLORS.send_button_hover
  assert(
    hc[1] == hoverExpected[1] and hc[2] == hoverExpected[2] and hc[3] == hoverExpected[3],
    "expected send_button_hover color on hover"
  )

  -- Leave: should revert to send_button
  assert(btn.scripts.OnLeave ~= nil, "expected OnLeave script")
  btn.scripts.OnLeave(btn)
  local lc = btn.sendBg.color
  assert(
    lc[1] == expected[1] and lc[2] == expected[2] and lc[3] == expected[3],
    "expected send_button color after leave"
  )

  -- Disabled state: should show disabled color
  composer.setEnabled(false)
  local dc = btn.sendBg.color
  local disabledExpected = Theme.COLORS.send_button_disabled
  assert(
    dc[1] == disabledExpected[1] and dc[2] == disabledExpected[2] and dc[3] == disabledExpected[3],
    "expected send_button_disabled color when disabled"
  )

  -- Hover while disabled: should NOT change color
  btn.scripts.OnEnter(btn)
  local dhc = btn.sendBg.color
  assert(
    dhc[1] == disabledExpected[1] and dhc[2] == disabledExpected[2] and dhc[3] == disabledExpected[3],
    "expected disabled color to remain on hover when disabled"
  )
  btn.scripts.OnLeave(btn)

  -- Re-enable: should restore accent color
  composer.setEnabled(true)
  local rc = btn.sendBg.color
  assert(
    rc[1] == expected[1] and rc[2] == expected[2] and rc[3] == expected[3],
    "expected send_button color after re-enabling"
  )

  print("PASS: test_send_button_hover")
end
