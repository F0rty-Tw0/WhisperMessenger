local FakeUI = require("tests.helpers.fake_ui")
local BubbleIcon = require("WhisperMessenger.UI.ChatBubble.BubbleIcon")
local SenderLabel = require("WhisperMessenger.UI.ChatBubble.SenderLabel")

-- Shift + left-click on a sender label or avatar hands the click to the
-- opener (which decides what to do); plain left-click stays inert.

local function withShift(isDown, fn)
  local original = _G.IsShiftKeyDown
  _G.IsShiftKeyDown = function()
    return isDown
  end
  fn()
  _G.IsShiftKeyDown = original
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, 600)

  local message = { direction = "in", kind = "user", text = "yo", sentAt = 1, playerName = "Bob-Realm", classTag = "MAGE", channel = "CHANNEL" }

  local function build(kind)
    local calls = {}
    local options = {
      openPlayerMenu = function(msg, anchor, button)
        calls[#calls + 1] = { message = msg, anchor = anchor, button = button }
        return true
      end,
    }
    local result
    if kind == "label" then
      result = SenderLabel.CreateSenderLabel(factory, parent, message, 400, 0, options)
    else
      result = BubbleIcon.CreateIcon(factory, parent, factory.CreateFrame("Frame", nil, parent), message, "in", options)
    end
    return result.frame, result.frame.scripts.OnMouseUp, calls
  end

  for _, kind in ipairs({ "label", "icon" }) do
    -- test_<kind>_shift_left_click_calls_opener_with_button
    local frame, handler, calls = build(kind)
    withShift(true, function()
      handler(frame, "LeftButton")
    end)
    assert(#calls == 1 and calls[1].button == "LeftButton", kind .. ": shift+left reaches opener with LeftButton")
    assert(calls[1].message == message and calls[1].anchor == frame, kind .. ": opener gets message and frame")

    -- test_<kind>_plain_left_click_does_not_call_opener
    frame, handler, calls = build(kind)
    withShift(false, function()
      handler(frame, "LeftButton")
    end)
    assert(#calls == 0, kind .. ": plain left click leaves opener alone")

    -- test_<kind>_right_click_still_calls_opener
    frame, handler, calls = build(kind)
    withShift(false, function()
      handler(frame, "RightButton")
    end)
    assert(#calls == 1 and calls[1].button == "RightButton", kind .. ": right click still reaches opener")
  end
end
