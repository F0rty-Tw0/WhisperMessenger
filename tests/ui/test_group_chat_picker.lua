local GroupChatDialogs = require("WhisperMessenger.UI.ContactsList.GroupChatDialogs")

-- The friend picker: a menu of friends to tick, confirmed with one button,
-- with "Type names…" for anyone not on the lists.
local function fakeMenuUtil()
  local menu = { opened = 0 }
  menu.api = {
    CreateContextMenu = function(owner, generator)
      menu.opened = menu.opened + 1
      menu.owner = owner
      menu.generator = generator
      menu.render()
    end,
  }
  function menu.render()
    local root = { titles = {}, checkboxes = {}, buttons = {} }
    function root:CreateTitle(text)
      self.titles[#self.titles + 1] = text
    end
    function root:CreateCheckbox(text, isSelected, setSelected)
      self.checkboxes[#self.checkboxes + 1] = { text = text, isSelected = isSelected, toggle = setSelected }
    end
    function root:CreateButton(text, onClick)
      self.buttons[#self.buttons + 1] = { text = text, click = onClick }
    end
    function root:CreateDivider() end
    menu.generator(menu.owner, root)
    menu.root = root
  end
  return menu
end

return function()
  local savedMenuUtil = _G.MenuUtil
  local savedShow = _G.StaticPopup_Show
  local savedDialogs = _G.StaticPopupDialogs
  _G.StaticPopupDialogs = {}
  local shown = {}
  _G.StaticPopup_Show = function(which)
    shown[#shown + 1] = which
    return {}
  end

  local log = {}
  local candidates = {
    { name = "Anna", label = "Anna", online = true },
    { name = "Lone Gazer", label = "Lone Gazer", online = false },
  }
  GroupChatDialogs.SetActions({
    CreateAndOpen = function(text)
      log[#log + 1] = { "create", text }
    end,
    AddMembers = function(item, text)
      log[#log + 1] = { "add", item, text }
    end,
    Candidates = function(exclude)
      log.exclude = exclude
      return candidates
    end,
    Members = function()
      return { "Bela" }
    end,
    CanManage = function()
      return true
    end,
  })

  -- test_create_picks_ticked_friends
  do
    local menu = fakeMenuUtil()
    _G.MenuUtil = menu.api
    local owner = {}
    assert(GroupChatDialogs.ShowCreate(owner) == true)
    assert(menu.owner == owner, "the menu opens at the clicked button")
    local root = menu.root
    assert(root.titles[1] == "Pick friends")
    assert(#root.checkboxes == 2, "one tick box per friend")
    assert(string.find(root.checkboxes[2].text, "offline", 1, true), "offline friends are marked")
    root.checkboxes[1].toggle()
    root.checkboxes[2].toggle()
    assert(root.checkboxes[1].isSelected() and root.checkboxes[2].isSelected())
    root.checkboxes[1].toggle()
    assert(not root.checkboxes[1].isSelected(), "ticking again unticks")
    assert(root.buttons[1].text == "Create group chat")
    root.buttons[1].click()
    assert(log[1][1] == "create" and log[1][2] == "Lone Gazer", tostring(log[1][2]))
  end

  -- test_nothing_ticked_creates_nothing
  do
    local menu = fakeMenuUtil()
    _G.MenuUtil = menu.api
    GroupChatDialogs.ShowCreate()
    local before = #log
    menu.root.buttons[1].click()
    assert(#log == before)
  end

  -- test_type_names_opens_the_text_box
  do
    local menu = fakeMenuUtil()
    _G.MenuUtil = menu.api
    GroupChatDialogs.ShowCreate()
    assert(menu.root.buttons[2].text == "Type names…")
    menu.root.buttons[2].click()
    assert(shown[#shown] == "WHISPER_MESSENGER_NEW_GROUP_CHAT")
  end

  -- test_add_people_leaves_out_members
  do
    local menu = fakeMenuUtil()
    _G.MenuUtil = menu.api
    local item = { channel = "WM_GROUP", conversationKey = "wmgroup::abcd1234", title = "Crew" }
    GroupChatDialogs.ShowAddPeople(item)
    assert(log.exclude[1] == "Bela", "current members are not offered")
    assert(menu.root.buttons[1].text == "Add to group chat")
    menu.root.checkboxes[1].toggle()
    menu.root.buttons[1].click()
    assert(log[#log][1] == "add" and log[#log][2] == item and log[#log][3] == "Anna")
  end

  -- test_empty_friend_list_says_so
  do
    candidates = {}
    local menu = fakeMenuUtil()
    _G.MenuUtil = menu.api
    GroupChatDialogs.ShowCreate()
    assert(menu.root.titles[2] == "No friends to show")
  end

  -- test_without_the_menu_api_it_falls_back_to_typing
  do
    _G.MenuUtil = nil
    GroupChatDialogs.ShowCreate()
    assert(shown[#shown] == "WHISPER_MESSENGER_NEW_GROUP_CHAT")
  end

  GroupChatDialogs.SetActions(nil)
  _G.MenuUtil = savedMenuUtil
  _G.StaticPopup_Show = savedShow
  _G.StaticPopupDialogs = savedDialogs
end
