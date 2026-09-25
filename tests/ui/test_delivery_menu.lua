local FakeUI = require("tests.helpers.fake_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local DeliveryMenu = require("WhisperMessenger.UI.ChatBubble.DeliveryMenu")

-- Small popup under a "(Not sent)" / "(Queued)" label listing what can be
-- done with the message. Styled like the reaction picker.

local function visibleLabels(menu)
  local labels = {}
  for _, button in ipairs(menu._buttons or {}) do
    if button.shown ~= false then
      labels[#labels + 1] = button._label.text
    end
  end
  return labels
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local savedUIParent, savedSpecialFrames = _G.UIParent, _G.UISpecialFrames
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UISpecialFrames = {}
  local anchor = factory.CreateFrame("Button", nil, _G.UIParent)
  local message = { direction = "out", text = "hi", delivery = "failed" }

  -- test_open_lists_actions_in_order
  do
    assert(DeliveryMenu.Open(factory, anchor, message, { "retry", "discard" }, function() end) == true, "opens")
    local labels = visibleLabels(DeliveryMenu.GetFrame())
    assert(#labels == 2 and labels[1] == "Retry" and labels[2] == "Discard", "Retry then Discard")
  end

  -- test_reopen_with_fewer_actions_hides_the_rest
  do
    DeliveryMenu.Open(factory, anchor, message, { "discard" }, function() end)
    local labels = visibleLabels(DeliveryMenu.GetFrame())
    assert(#labels == 1 and labels[1] == "Discard", "only Discard")
  end

  -- test_clicking_an_action_reports_it_and_closes
  do
    local got
    DeliveryMenu.Open(factory, anchor, message, { "retry", "discard" }, function(m, action)
      got = { message = m, action = action }
    end)
    local menu = DeliveryMenu.GetFrame()
    menu._buttons[2].scripts.OnClick(menu._buttons[2])
    assert(got and got.message == message and got.action == "discard", "Discard reported")
    assert(menu.shown == false, "menu closed")
  end

  -- test_outside_click_dismisses_once_armed
  do
    DeliveryMenu.Open(factory, anchor, message, { "retry" }, function() end)
    local menu = DeliveryMenu.GetFrame()
    menu.scripts.OnEvent(menu, "GLOBAL_MOUSE_DOWN")
    assert(menu.shown == true, "the opening click does not close it")
    menu.scripts.OnUpdate(menu)
    menu.scripts.OnEvent(menu, "GLOBAL_MOUSE_DOWN")
    assert(menu.shown == false, "a later outside click closes it")
  end

  -- test_escape_closes_the_menu
  do
    local registered = false
    for _, name in ipairs(_G.UISpecialFrames) do
      registered = registered or name == "WhisperMessengerDeliveryMenu"
    end
    assert(registered, "Escape closes the menu")
  end

  -- test_no_actions_opens_nothing
  do
    assert(DeliveryMenu.Open(factory, anchor, message, {}, function() end) == false, "nothing to show")
  end

  DeliveryMenu.Close()
  _G.UIParent, _G.UISpecialFrames = savedUIParent, savedSpecialFrames
end
