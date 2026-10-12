local FakeUI = require("tests.helpers.fake_ui")

-- Without a pane opener, sender labels and avatars fall back to
-- ns.ChatBubblePlayerMenu. That fallback opens the menu on right-click only:
-- shift + left-click must not pop it up.

local SOURCES = {
  label = "UI/ChatBubble/SenderLabel.lua",
  icon = "UI/ChatBubble/BubbleIcon.lua",
}

local function loadWithMenu(path)
  local opened = { count = 0 }
  local ns = {
    ChatBubblePlayerMenu = {
      Open = function()
        opened.count = opened.count + 1
        return true
      end,
    },
  }
  local module = assert(loadfile(path))("WhisperMessenger", ns)
  return module, opened
end

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
    local module, opened = loadWithMenu(SOURCES[kind])
    local result
    if kind == "label" then
      result = module.CreateSenderLabel(factory, parent, message, 400, 0, {})
    else
      result = module.CreateIcon(factory, parent, factory.CreateFrame("Frame", nil, parent), message, "in", {})
    end
    return result.frame, result.frame.scripts.OnMouseUp, opened
  end

  for _, kind in ipairs({ "label", "icon" }) do
    -- test_<kind>_fallback_ignores_shift_left_click
    local frame, handler, opened = build(kind)
    withShift(true, function()
      handler(frame, "LeftButton")
    end)
    assert(opened.count == 0, kind .. ": shift + left must not open the fallback menu")

    -- test_<kind>_fallback_opens_menu_on_right_click
    frame, handler, opened = build(kind)
    withShift(false, function()
      handler(frame, "RightButton")
    end)
    assert(opened.count == 1, kind .. ": right click opens the fallback menu")
  end
end
