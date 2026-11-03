local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local Localization = require("WhisperMessenger.Locale.Localization")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")
local FakeUI = require("tests.helpers.fake_ui")

-- "Notify when they change zone" checkbox in the whisper-row menu, only where
-- WoW shows the contact's zone (Battle.net friends in WoW, guild/community
-- members).

local LABEL = "Notify when they change zone"

local function newRoot(withCheckbox)
  local root = { entries = {} }
  function root:CreateButton(text, callback)
    local entry = { kind = "button", text = text, callback = callback }
    self.entries[#self.entries + 1] = entry
    return entry
  end
  if withCheckbox then
    function root:CreateCheckbox(text, isSelected, setSelected)
      local entry = { kind = "checkbox", text = text, isSelected = isSelected, setSelected = setSelected }
      self.entries[#self.entries + 1] = entry
      return entry
    end
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
  PresenceCache._reset()
  PresenceCache._setCache({ ["Player-GUILD"] = "online" })
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
  _G.C_FriendList = nil
  local updates = {}
  local function onUpdatePrefs(item, changes)
    updates[#updates + 1] = { item = item, changes = changes }
  end

  local function menuFor(item, withCheckbox)
    ContextMenu.Open(item, anchor, function() end, onUpdatePrefs)
    local root = newRoot(withCheckbox ~= false)
    local tag = item.channel == "BN" and "MENU_UNIT_BN_FRIEND" or "MENU_UNIT_FRIEND"
    modifiers[tag](anchor, root, openedContext)
    return root
  end

  -- test_bnet_friend_in_wow_gets_checkbox
  local bnet = { channel = "BN", displayName = "Anduin#1", conversationKey = "bnet::anduin", bnetAccountID = 7, areaName = "Dornogal" }
  local entry = find(menuFor(bnet), LABEL)
  assert(entry and entry.kind == "checkbox", "Battle.net friend in WoW: checkbox entry")
  assert(entry.isSelected() == false, "unchecked by default")
  entry.setSelected()
  assert(updates[1].item == bnet and updates[1].changes.notifyZone == true, "checking arms it")

  -- test_open_menu_shows_tick_right_after_click
  assert(entry.isSelected() == true, "open menu shows the tick after click")
  entry.setSelected()
  assert(updates[2].changes.notifyZone == false, "second click in same menu disarms it")
  assert(entry.isSelected() == false, "open menu clears the tick after second click")
  updates = {}

  -- test_armed_contact_shows_checked_and_turns_off
  local away = { channel = "BN", displayName = "Anduin#1", conversationKey = "bnet::anduin", bnetAccountID = 7, notifyZone = true }
  entry = find(menuFor(away), LABEL)
  assert(entry and entry.isSelected() == true, "armed: shown checked even without a zone")
  entry.setSelected()
  assert(updates[1].changes.notifyZone == false, "unchecking disarms it")

  -- test_guild_member_gets_checkbox
  local guildie = { channel = "WOW", displayName = "Jaina-Realm", conversationKey = "wow::jaina", guid = "Player-GUILD" }
  assert(find(menuFor(guildie), LABEL) ~= nil, "guild member: entry shown")

  -- test_bnet_friend_outside_wow_has_no_entry
  local app = { channel = "BN", displayName = "Varian#1", conversationKey = "bnet::varian", bnetAccountID = 8 }
  assert(find(menuFor(app), LABEL) == nil, "no zone visible: no entry")

  -- test_stranger_has_no_entry
  local stranger = { channel = "WOW", displayName = "Rando-Realm", conversationKey = "wow::rando", guid = "Player-X" }
  assert(find(menuFor(stranger), LABEL) == nil, "stranger: no entry")

  -- test_client_without_checkbox_gets_a_button
  entry = find(menuFor(bnet, false), LABEL)
  assert(entry and entry.kind == "button", "older menu API: plain button")

  PresenceCache._reset()
  _G.Menu = saved.Menu
  rawset(_G, "UnitPopup_OpenMenu", saved.UnitPopup_OpenMenu)
  _G.C_FriendList = saved.C_FriendList
end
