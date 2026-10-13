local FakeUI = require("tests.helpers.fake_ui")
local PlayerMenuClick = require("WhisperMessenger.UI.ChatBubble.PlayerMenuClick")

local function withShift(isDown, fn)
  local original = rawget(_G, "IsShiftKeyDown")
  rawset(_G, "IsShiftKeyDown", function()
    return isDown
  end)
  fn()
  rawset(_G, "IsShiftKeyDown", original)
end

return function()
  local factory = FakeUI.NewFactory()
  local message = { direction = "in", playerName = "Bob-Realm" }

  -- test_right_click_calls_opener_with_message_frame_and_button
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local calls = {}
    PlayerMenuClick.Attach(frame, message, function(msg, anchor, button)
      calls[#calls + 1] = { message = msg, anchor = anchor, button = button }
    end)
    frame.scripts.OnMouseUp(frame, "RightButton")
    assert(#calls == 1, "right-click should call the opener once")
    assert(calls[1].message == message and calls[1].anchor == frame and calls[1].button == "RightButton")
  end

  -- test_plain_left_click_does_not_call_opener
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local calls = 0
    PlayerMenuClick.Attach(frame, message, function()
      calls = calls + 1
    end)
    withShift(false, function()
      frame.scripts.OnMouseUp(frame, "LeftButton")
    end)
    assert(calls == 0, "plain left-click must stay inert")
  end

  -- test_shift_left_click_calls_opener
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local button = nil
    PlayerMenuClick.Attach(frame, message, function(_msg, _anchor, clicked)
      button = clicked
    end)
    withShift(true, function()
      frame.scripts.OnMouseUp(frame, "LeftButton")
    end)
    assert(button == "LeftButton", "shift + left-click should reach the opener")
  end

  -- test_without_opener_right_click_opens_player_menu
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local opened = nil
    local ns = {
      ChatBubblePlayerMenu = {
        Open = function(msg, anchor)
          opened = { message = msg, anchor = anchor }
          return true
        end,
      },
    }
    local module = assert(loadfile("UI/ChatBubble/PlayerMenuClick.lua"))("WhisperMessenger", ns)
    module.Attach(frame, message, nil)
    frame.scripts.OnMouseUp(frame, "RightButton")
    assert(opened ~= nil and opened.message == message and opened.anchor == frame, "default opener should open the player menu")
  end
end
