local RowScripts = require("WhisperMessenger.UI.ContactsList.RowScripts")
local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")

local factory = FakeUI.NewFactory()

-- A bound row plus spies: result.menu = items the contact menu opened for,
-- result.selected = how often onSelect ran.
local function boundRow()
  local row = factory.CreateFrame("Button", nil, nil)
  local item = { conversationKey = "k", displayName = "Arthas", channel = "WOW" }
  row.item = item
  local result = { menu = {}, selected = 0 }
  RowScripts.bindClick(row, item, {
    onSelect = function()
      result.selected = result.selected + 1
    end,
  })
  return row, item, result
end

local function withMenuSpy(result, fn)
  local original = ContextMenu.Open
  rawset(ContextMenu, "Open", function(target)
    result.menu[#result.menu + 1] = target
    return true
  end)
  local ok, err = pcall(fn)
  rawset(ContextMenu, "Open", original)
  assert(ok, err)
end

return function()
  -- test_bound_row_has_no_button_context
  -- The game's buff refresh reads buttonContext on the focused frame; an
  -- addon value there taints it.
  do
    local row = boundRow()
    assert(row.buttonContext == nil, "a contact row carries no buttonContext")
  end

  -- test_game_right_click_on_a_row_opens_the_contact_menu_and_does_not_select
  do
    local env = FakeGamepad.New()
    local row, item, result = boundRow()
    withMenuSpy(result, function()
      env.rightClick(row)
    end)
    assert(#result.menu == 1 and result.menu[1] == item, "same menu as a mouse right-click")
    assert(result.selected == 0, "a right-click does not select the chat")
  end

  -- test_a_on_a_row_still_only_selects
  do
    local row, _, result = boundRow()
    withMenuSpy(result, function()
      row.scripts.OnClick(row, "LeftButton")
      row.scripts.OnClick(row, nil)
    end)
    assert(result.selected == 2 and #result.menu == 0, "A (LeftButton or no button) selects, never opens the menu")
  end
end
