local FakeUI = require("tests.helpers.fake_ui")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")

-- Shift + left-click on the widget or minimap icon marks everything read and
-- leaves the window alone; a plain left-click still toggles the window.
local function createIcons(factory, calls)
  local options = {
    onToggle = function()
      calls.toggle = calls.toggle + 1
    end,
    onMarkAllRead = function()
      calls.markAllRead = calls.markAllRead + 1
    end,
  }
  return {
    widget = ToggleIcon.Create(factory, options),
    minimap = MinimapIcon.Create(factory, {
      parent = factory.CreateFrame("Frame", "Minimap", nil),
      onToggle = options.onToggle,
      onMarkAllRead = options.onMarkAllRead,
    }),
  }
end

return function()
  local savedIsShiftKeyDown = _G.IsShiftKeyDown
  local shiftDown = false
  _G.IsShiftKeyDown = function()
    return shiftDown
  end

  for _, name in ipairs({ "widget", "minimap" }) do
    local calls = { toggle = 0, markAllRead = 0 }
    local icon = createIcons(FakeUI.NewFactory(), calls)[name]
    local onClick = icon.frame.scripts.OnClick

    -- test_shift_left_click_marks_all_read_without_toggling
    shiftDown = true
    onClick(icon.frame, "LeftButton")
    assert(calls.markAllRead == 1, name .. ": shift-click marks all read")
    assert(calls.toggle == 0, name .. ": shift-click leaves the window alone")

    -- test_plain_left_click_toggles_window
    shiftDown = false
    onClick(icon.frame, "LeftButton")
    assert(calls.toggle == 1, name .. ": plain click toggles the window")
    assert(calls.markAllRead == 1, name .. ": plain click does not mark read")
  end

  _G.IsShiftKeyDown = savedIsShiftKeyDown
end
