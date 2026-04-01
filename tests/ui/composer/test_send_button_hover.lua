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

  assert(btn.sendBg ~= nil, "expected sendBg texture on button")
  assert(btn.sendBorderTop == nil, "expected sendBorderTop to be removed")
  assert(btn.label ~= nil, "expected send button label")

  local expected = Theme.COLORS.send_button
  local c = btn.sendBg.color
  assert(c ~= nil, "expected sendBg to have a color")
  assert(
    c[1] == expected[1] and c[2] == expected[2] and c[3] == expected[3],
    "expected send_button color, got: " .. tostring(c[1]) .. "," .. tostring(c[2]) .. "," .. tostring(c[3])
  )

  local expectedText = Theme.COLORS.send_button_text or Theme.COLORS.text_primary
  assert(
    btn.label.textColor[1] == expectedText[1]
      and btn.label.textColor[2] == expectedText[2]
      and btn.label.textColor[3] == expectedText[3],
    "expected send button label color token"
  )

  assert(btn.scripts.OnEnter ~= nil, "expected OnEnter script")
  btn.scripts.OnEnter(btn)

  local hoverExpected = Theme.COLORS.send_button_hover
  local hc = btn.sendBg.color
  assert(
    hc[1] == hoverExpected[1] and hc[2] == hoverExpected[2] and hc[3] == hoverExpected[3],
    "expected send_button_hover color on hover"
  )

  assert(btn.scripts.OnLeave ~= nil, "expected OnLeave script")
  btn.scripts.OnLeave(btn)

  local lc = btn.sendBg.color
  assert(
    lc[1] == expected[1] and lc[2] == expected[2] and lc[3] == expected[3],
    "expected send_button color after leave"
  )

  composer.setEnabled(false)
  local disabledExpected = Theme.COLORS.send_button_disabled
  local dc = btn.sendBg.color
  assert(
    dc[1] == disabledExpected[1] and dc[2] == disabledExpected[2] and dc[3] == disabledExpected[3],
    "expected send_button_disabled color when disabled"
  )

  local disabledTextExpected = Theme.COLORS.send_button_text_disabled or Theme.COLORS.text_secondary
  assert(
    btn.label.textColor[1] == disabledTextExpected[1]
      and btn.label.textColor[2] == disabledTextExpected[2]
      and btn.label.textColor[3] == disabledTextExpected[3],
    "expected disabled send button text color token"
  )

  btn.scripts.OnEnter(btn)
  local dhc = btn.sendBg.color
  assert(
    dhc[1] == disabledExpected[1] and dhc[2] == disabledExpected[2] and dhc[3] == disabledExpected[3],
    "expected disabled color to remain on hover when disabled"
  )
  btn.scripts.OnLeave(btn)

  composer.setEnabled(true)
  local rc = btn.sendBg.color
  assert(
    rc[1] == expected[1] and rc[2] == expected[2] and rc[3] == expected[3],
    "expected send_button color after re-enabling"
  )
  assert(
    btn.label.textColor[1] == expectedText[1]
      and btn.label.textColor[2] == expectedText[2]
      and btn.label.textColor[3] == expectedText[3],
    "expected send button text color after re-enabling"
  )

  print("PASS: test_send_button_hover")
end