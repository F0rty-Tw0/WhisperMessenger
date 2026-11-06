local GroupChatDialogs = require("WhisperMessenger.UI.ContactsList.GroupChatDialogs")

local function fakeActions(log)
  return {
    CreateAndOpen = function(text)
      log[#log + 1] = { "create", text }
    end,
    AddMembers = function(item, text)
      log[#log + 1] = { "add", item, text }
    end,
    Rename = function(item, text)
      log[#log + 1] = { "rename", item, text }
    end,
    Leave = function(item)
      log[#log + 1] = { "leave", item }
    end,
    CanManage = function(item)
      return item.left ~= true
    end,
  }
end

local function fakeMenu()
  local menu = { buttons = {} }
  function menu:CreateButton(label, onClick)
    self.buttons[#self.buttons + 1] = { label = label, onClick = onClick }
  end
  return menu
end

return function()
  local savedShow = _G.StaticPopup_Show
  local savedDialogs = _G.StaticPopupDialogs
  local shown = {}
  _G.StaticPopupDialogs = {}
  _G.StaticPopup_Show = function(which, textArg, _, data)
    shown[#shown + 1] = { which = which, textArg = textArg, data = data }
    return {}
  end

  -- test_nothing_shows_without_actions
  do
    GroupChatDialogs.SetActions(nil)
    assert(GroupChatDialogs.HasActions() == false)
    assert(GroupChatDialogs.ShowCreate() == false)
    local menu = fakeMenu()
    GroupChatDialogs.AddMenuEntries(menu, { channel = "WM_GROUP" })
    assert(#menu.buttons == 0)
  end

  local log = {}
  GroupChatDialogs.SetActions(fakeActions(log))

  -- test_create_popup_hands_the_typed_names_to_the_action
  do
    assert(GroupChatDialogs.ShowCreate() == true)
    assert(shown[#shown].which == "WHISPER_MESSENGER_NEW_GROUP_CHAT")
    _G.StaticPopupDialogs.WHISPER_MESSENGER_NEW_GROUP_CHAT._wmOnAccept("Anna, Bela")
    assert(log[1][1] == "create" and log[1][2] == "Anna, Bela")
  end

  -- test_group_chat_rows_get_add_rename_and_leave
  do
    local item = { channel = "WM_GROUP", conversationKey = "wmgroup::abcd1234", title = "Crew" }
    local menu = fakeMenu()
    GroupChatDialogs.AddMenuEntries(menu, item)
    assert(#menu.buttons == 3, "three entries")
    assert(menu.buttons[1].label == "Add people…" and menu.buttons[2].label == "Rename…" and menu.buttons[3].label == "Leave group chat")

    menu.buttons[1].onClick()
    assert(shown[#shown].which == "WHISPER_MESSENGER_GROUP_CHAT_ADD" and shown[#shown].textArg == "Crew")
    _G.StaticPopupDialogs.WHISPER_MESSENGER_GROUP_CHAT_ADD._wmOnAccept("Csilla")
    assert(log[#log][1] == "add" and log[#log][2] == item and log[#log][3] == "Csilla")

    menu.buttons[2].onClick()
    assert(shown[#shown].which == "WHISPER_MESSENGER_GROUP_CHAT_RENAME")
    _G.StaticPopupDialogs.WHISPER_MESSENGER_GROUP_CHAT_RENAME._wmOnAccept("Raid crew")
    assert(log[#log][1] == "rename" and log[#log][3] == "Raid crew")

    menu.buttons[3].onClick()
    local leave = shown[#shown]
    assert(leave.which == "WHISPER_MESSENGER_GROUP_CHAT_LEAVE" and leave.data == item, "the popup carries the row")
    _G.StaticPopupDialogs.WHISPER_MESSENGER_GROUP_CHAT_LEAVE.OnAccept({}, leave.data)
    assert(log[#log][1] == "leave" and log[#log][2] == item)
  end

  -- test_other_rows_and_left_chats_get_no_entries
  do
    local menu = fakeMenu()
    GroupChatDialogs.AddMenuEntries(menu, { channel = "PARTY" })
    GroupChatDialogs.AddMenuEntries(menu, { channel = "WM_GROUP", left = true })
    assert(#menu.buttons == 0)
  end

  GroupChatDialogs.SetActions(nil)
  _G.StaticPopup_Show = savedShow
  _G.StaticPopupDialogs = savedDialogs
end
