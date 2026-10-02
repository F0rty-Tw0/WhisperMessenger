local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local Localization = require("WhisperMessenger.Locale.Localization")
local FakeUI = require("tests.helpers.fake_ui")

-- The right-click menu offers Pin/Unpin and Remove (the hover buttons'
-- actions) in the full list and the collapsed rail alike, through the same
-- onPin / onRemove handlers the hover buttons call.

local function newRoot()
  local root = { buttons = {} }
  function root:CreateButton(text, callback)
    local button = { text = text, callback = callback }
    self.buttons[#self.buttons + 1] = button
    return button
  end
  return root
end

local function findButton(root, text)
  for _, button in ipairs(root.buttons) do
    if button.text == text then
      return button
    end
  end
  return nil
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local anchor = factory.CreateFrame("Button", nil, nil)
  local saved = { Menu = _G.Menu, UnitPopup_OpenMenu = _G.UnitPopup_OpenMenu, MenuUtil = _G.MenuUtil }

  local modifiers, openedContext, groupGenerator = {}, nil, nil
  _G.Menu = {
    ModifyMenu = function(tag, callback)
      modifiers[tag] = callback
    end,
  }
  rawset(_G, "UnitPopup_OpenMenu", function(_, contextData)
    openedContext = contextData
  end)
  _G.MenuUtil = {
    CreateContextMenu = function(_owner, generator)
      groupGenerator = generator
    end,
  }

  local calls = {}
  local actions = {
    onPin = function(item)
      calls[#calls + 1] = { action = "pin", item = item }
    end,
    onRemove = function(item)
      calls[#calls + 1] = { action = "remove", item = item }
    end,
  }

  local function whisperMenu(item, rowActions)
    ContextMenu.Open(item, anchor, nil, nil, rowActions)
    local root = newRoot()
    modifiers["MENU_UNIT_FRIEND"](anchor, root, openedContext)
    return root
  end

  -- test_unpinned_whisper_offers_pin_and_remove
  do
    local item = { channel = "WOW", displayName = "Arthas", conversationKey = "wow::arthas" }
    local root = whisperMenu(item, actions)
    findButton(root, "Pin to top").callback()
    findButton(root, "Remove").callback()
    assert(calls[1].action == "pin" and calls[1].item == item, "Pin calls the pin handler with the row's item")
    assert(calls[2].action == "remove" and calls[2].item == item, "Remove calls the remove handler")
    assert(findButton(root, "Unpin") == nil, "no Unpin on an unpinned contact")
  end

  -- test_pinned_whisper_offers_unpin
  do
    local root = whisperMenu({ channel = "WOW", displayName = "Jaina", pinned = true }, actions)
    assert(findButton(root, "Unpin") ~= nil and findButton(root, "Pin to top") == nil, "pinned contact offers Unpin")
  end

  -- test_group_rows_get_pin_and_remove_like_their_hover_buttons
  do
    ContextMenu.Open({ channel = "GUILD", displayName = "Guild" }, anchor, nil, nil, actions)
    local root = newRoot()
    assert(groupGenerator ~= nil, "group menu built")
    groupGenerator(anchor, root)
    assert(findButton(root, "Pin to top") ~= nil and findButton(root, "Remove") ~= nil, "group menu has pin and remove")
  end

  -- test_no_handlers_no_entries
  do
    local root = whisperMenu({ channel = "WOW", displayName = "Thrall" }, nil)
    assert(findButton(root, "Pin to top") == nil and findButton(root, "Remove") == nil, "nothing to call, nothing shown")
  end

  -- test_rail_and_full_rows_reach_the_hover_buttons_handlers
  for _, compact in ipairs({ true, false }) do
    calls = {}
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(compact and 50 or 260, 400)
    local item = { channel = "WOW", displayName = "Sylvanas", conversationKey = "wow::sylvanas" }
    local row = RowView.bindRow(factory, parent, nil, 1, item, {
      compact = compact,
      onPin = actions.onPin,
      onRemove = actions.onRemove,
    })
    row.scripts.OnClick(row, "RightButton")
    local root = newRoot()
    modifiers["MENU_UNIT_FRIEND"](anchor, root, openedContext)
    findButton(root, "Pin to top").callback()
    row.pinButton.scripts.OnClick(row.pinButton)
    local mode = compact and "rail" or "full list"
    assert(#calls == 2 and calls[1].item == item and calls[2].item == item, mode .. ": menu and hover button pin the same item")
    assert(calls[1].action == calls[2].action, mode .. ": through the same handler")
  end

  _G.Menu, _G.UnitPopup_OpenMenu, _G.MenuUtil = saved.Menu, saved.UnitPopup_OpenMenu, saved.MenuUtil
end
