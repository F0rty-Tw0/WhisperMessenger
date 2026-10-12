local RowScripts = require("WhisperMessenger.UI.ContactsList.RowScripts")
local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local FakeUI = require("tests.helpers.fake_ui")

-- Shift + left-click on a WoW whisper row sends a visible /who and never
-- selects the chat; every other click keeps its old meaning.

local factory = FakeUI.NewFactory()
local parent = factory.CreateFrame("Frame", nil, nil)
parent:SetSize(260, 400)

local function click(channel, button, shift, whoResult)
  local row = factory.CreateFrame("Button", nil, parent)
  local item = { conversationKey = "k", displayName = "Alice-Area52", channel = channel }
  row.item = item
  local result = { selected = false, whoNames = {}, menuOpened = false }
  local options = {
    onSelect = function()
      result.selected = true
    end,
    whoPlayer = function(name)
      result.whoNames[#result.whoNames + 1] = name
      return whoResult
    end,
  }
  local originalShift = _G.IsShiftKeyDown
  local originalOpen = ContextMenu.Open
  _G.IsShiftKeyDown = function()
    return shift
  end
  rawset(ContextMenu, "Open", function()
    result.menuOpened = true
    return true
  end)
  RowScripts.bindClick(row, item, options)
  row.scripts.OnClick(row, button)
  _G.IsShiftKeyDown = originalShift
  rawset(ContextMenu, "Open", originalOpen)
  return result
end

return function()
  -- test_shift_left_click_on_wow_row_sends_who_without_selecting
  do
    local result = click("WOW", "LeftButton", true, true)
    assert(#result.whoNames == 1 and result.whoNames[1] == "Alice-Area52", "whoPlayer called with the display name")
    assert(result.selected == false, "onSelect must not run on shift-click")
  end

  -- test_plain_left_click_selects_without_who
  do
    local result = click("WOW", "LeftButton", false, true)
    assert(result.selected == true, "onSelect runs on plain click")
    assert(#result.whoNames == 0, "whoPlayer not called on plain click")
  end

  -- test_shift_left_click_on_bn_row_selects_without_who
  do
    local result = click("BN", "LeftButton", true, true)
    assert(result.selected == true, "onSelect runs for a BN row")
    assert(#result.whoNames == 0, "whoPlayer not called for a BN row")
  end

  -- test_shift_right_click_still_opens_the_menu
  do
    local result = click("WOW", "RightButton", true, true)
    assert(result.menuOpened == true, "menu opens on shift + right-click")
    assert(result.selected == false and #result.whoNames == 0, "no select, no who")
  end

  -- test_shift_left_click_without_who_callback_selects
  do
    local row = factory.CreateFrame("Button", nil, parent)
    local item = { conversationKey = "k", displayName = "Alice", channel = "WOW" }
    row.item = item
    local selected = false
    local originalShift = _G.IsShiftKeyDown
    _G.IsShiftKeyDown = function()
      return true
    end
    RowScripts.bindClick(row, item, {
      onSelect = function()
        selected = true
      end,
    })
    row.scripts.OnClick(row, "LeftButton")
    _G.IsShiftKeyDown = originalShift
    assert(selected == true, "no whoPlayer option -> plain select")
  end
end
