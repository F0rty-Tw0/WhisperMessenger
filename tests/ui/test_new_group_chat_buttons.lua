local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local StartConversationDialog = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Buttons.StartConversationDialog")
local HeaderElements = require("WhisperMessenger.UI.ConversationPane.HeaderElements")
local GroupChatDialogs = require("WhisperMessenger.UI.ContactsList.GroupChatDialogs")

-- On the Groups tab the title-bar New Whisper button and the empty-state
-- button start a group chat instead.
return function()
  local savedShow = _G.StaticPopup_Show
  local savedDialogs = _G.StaticPopupDialogs
  local shown = {}
  _G.StaticPopupDialogs = {}
  _G.StaticPopup_Show = function(which)
    shown[#shown + 1] = which
    return {}
  end
  GroupChatDialogs.SetActions({
    CreateAndOpen = function() end,
    CanManage = function()
      return true
    end,
  })
  local factory = FakeUI.NewFactory()

  -- test_title_button_follows_the_tab
  do
    local mode = "whispers"
    local button = factory.CreateFrame("Button", nil, nil)
    StartConversationDialog.Wire(button, {
      onStartConversation = function() end,
      getTabMode = function()
        return mode
      end,
    })
    button.scripts.OnClick(button)
    assert(shown[#shown] == "WHISPER_MESSENGER_START_CONVERSATION", "whispers tab: new whisper")
    mode = "groups"
    assert(button._wmIsGroupMode() == true)
    button.scripts.OnClick(button)
    assert(shown[#shown] == "WHISPER_MESSENGER_NEW_GROUP_CHAT", "groups tab: new group chat")
    mode = "channels"
    button.scripts.OnClick(button)
    assert(shown[#shown] == "WHISPER_MESSENGER_START_CONVERSATION", "channels tab: new whisper")
  end

  -- test_empty_state_offers_a_group_chat_on_the_groups_tab
  do
    local pane = factory.CreateFrame("Frame", nil, nil)
    local container = HeaderElements.createEmptyState(pane, nil, factory, true)
    local button = FindUI.ofType(container, "Button")[1]
    container.setMode("groups")
    assert(button:IsShown(), "the button shows on Groups")
    assert(button.text == "New Group Chat", "labelled for group chats, got " .. tostring(button.text))
    button.scripts.OnClick(button)
    assert(shown[#shown] == "WHISPER_MESSENGER_NEW_GROUP_CHAT")
    container.setMode("channels")
    assert(not button:IsShown(), "Channels has no button")
    container.setMode("whispers")
    assert(button.text == "Start New Whisper")
  end

  -- test_without_group_chats_the_groups_tab_has_no_button
  do
    GroupChatDialogs.SetActions(nil)
    local pane = factory.CreateFrame("Frame", nil, nil)
    local container = HeaderElements.createEmptyState(pane, nil, factory, true)
    local button = FindUI.ofType(container, "Button")[1]
    container.setMode("groups")
    assert(not button:IsShown())
  end

  GroupChatDialogs.SetActions(nil)
  _G.StaticPopup_Show = savedShow
  _G.StaticPopupDialogs = savedDialogs
end
