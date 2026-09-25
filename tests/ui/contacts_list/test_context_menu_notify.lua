local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local Localization = require("WhisperMessenger.Locale.Localization")
local FakeUI = require("tests.helpers.fake_ui")

-- "Notify when online" checkbox in the whisper-row menu, only for friends
-- whose online state WoW reports (character friends, Battle.net friends).

local LABEL = "Notify when online"

local function newRoot()
  local root = { entries = {} }
  function root:CreateButton(text, callback)
    local entry = { kind = "button", text = text, callback = callback }
    self.entries[#self.entries + 1] = entry
    return entry
  end
  function root:CreateCheckbox(text, isSelected, setSelected)
    local entry = { kind = "checkbox", text = text, isSelected = isSelected, setSelected = setSelected }
    self.entries[#self.entries + 1] = entry
    return entry
  end
  return root
end

local function find(root, text)
  for _, entry in ipairs(root.entries) do
    if entry.text == text then
      return entry
    end
  end
  return nil
end

return function()
  Localization.Configure({ language = "enUS" })
  local anchor = FakeUI.NewFactory().CreateFrame("Button", nil, nil)
  local saved = { Menu = _G.Menu, UnitPopup_OpenMenu = _G.UnitPopup_OpenMenu, C_FriendList = _G.C_FriendList }
  local modifiers, openedContext = {}, nil
  _G.Menu = {
    ModifyMenu = function(tag, callback)
      modifiers[tag] = callback
    end,
  }
  rawset(_G, "UnitPopup_OpenMenu", function(_, contextData)
    openedContext = contextData
  end)
  _G.C_FriendList = {
    IsFriend = function(guid)
      return guid == "Player-FRIEND"
    end,
  }
  local updates = {}
  local function onUpdatePrefs(item, changes)
    updates[#updates + 1] = { item = item, changes = changes }
  end

  local function menuFor(item)
    ContextMenu.Open(item, anchor, function() end, onUpdatePrefs)
    local root = newRoot()
    local tag = item.channel == "BN" and "MENU_UNIT_BN_FRIEND" or "MENU_UNIT_FRIEND"
    modifiers[tag](anchor, root, openedContext)
    return root
  end

  -- test_character_friend_gets_checkbox
  local friend = { channel = "WOW", displayName = "Jaina-Realm", conversationKey = "wow::jaina", guid = "Player-FRIEND" }
  local entry = find(menuFor(friend), LABEL)
  assert(entry and entry.kind == "checkbox", "character friend: checkbox entry")
  assert(entry.isSelected() == false, "unchecked by default")
  entry.setSelected()
  assert(updates[1].item == friend and updates[1].changes.notifyOnline == true, "checking turns it on")

  -- test_open_menu_shows_tick_right_after_click
  -- The menu stays open after a checkbox click and re-reads isSelected.
  assert(entry.isSelected() == true, "open menu shows the tick after click")
  entry.setSelected()
  assert(updates[2].changes.notifyOnline == false, "second click in same menu turns it off")
  assert(entry.isSelected() == false, "open menu clears the tick after second click")
  updates = {}

  -- test_checked_state_turns_it_off
  friend.notifyOnline = true
  entry = find(menuFor(friend), LABEL)
  assert(entry.isSelected() == true, "shows checked")
  entry.setSelected()
  assert(updates[1].changes.notifyOnline == false, "unchecking turns it off")

  -- test_battle_net_friend_gets_checkbox
  local bnet = { channel = "BN", displayName = "Anduin#1", conversationKey = "bnet::anduin", bnetAccountID = 7 }
  assert(find(menuFor(bnet), LABEL) ~= nil, "Battle.net friend: entry shown")

  -- test_stranger_has_no_entry
  local stranger = { channel = "WOW", displayName = "Rando-Realm", conversationKey = "wow::rando", guid = "Player-X" }
  assert(find(menuFor(stranger), LABEL) == nil, "not a friend: no entry")

  _G.Menu = saved.Menu
  rawset(_G, "UnitPopup_OpenMenu", saved.UnitPopup_OpenMenu)
  _G.C_FriendList = saved.C_FriendList
end
