-- The conversation pane's empty state must follow the Whispers/Groups tab:
-- the Groups tab shows group-chat copy instead of "Start New Whisper".

local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")

local function createWindow(factory, initialTabMode)
  return MessengerWindow.Create(factory, {
    title = "WhisperMessenger",
    contacts = {},
    selectedContact = nil,
    conversation = nil,
    initialTabMode = initialTabMode,
    onSelectConversation = function()
      return { contacts = {}, selectedContact = nil, conversation = nil }
    end,
    onSend = function() end,
    onClose = function() end,
  })
end

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_switching_to_groups_tab_shows_group_copy
  do
    local window = createWindow(factory, "whispers")
    local emptyState = window.conversation.headerEmpty
    assert(FindUI.text(emptyState, "Welcome to WhisperMessenger") ~= nil, "whispers tab starts with welcome copy")
    window.setTabMode("groups")
    assert(FindUI.text(emptyState, "Group Chats") ~= nil, "groups tab should show group copy")
    window.setTabMode("whispers")
    assert(FindUI.text(emptyState, "Welcome to WhisperMessenger") ~= nil, "whispers tab should restore welcome copy")
  end

  -- test_initial_groups_tab_shows_group_copy
  do
    local window = createWindow(factory, "groups")
    assert(FindUI.text(window.conversation.headerEmpty, "Group Chats") ~= nil, "window opened on groups tab should show group copy")
  end

  _G.UIParent = savedUIParent
end
