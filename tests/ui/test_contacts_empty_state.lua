local FakeUI = require("tests.helpers.fake_ui")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local ContactsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRuntime")

local WHISPERS_EMPTY_MSG = "No conversations yet. Click Start New Whisper to message a friend."
local GROUPS_EMPTY_MSG = "No group chats yet.\nJoin a party or instance to see messages here."

local function makeItem(channel)
  return { channel = channel, displayName = "test", conversationKey = "k-" .. tostring(channel) }
end

local function makeRuntime(factory, initialContacts, contactsSearchInput, extraOptions)
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(200, 400)
  local contactsView = ScrollView.Create(factory, parent, { width = 200, height = 400 })

  local options = {
    contactsView = contactsView,
    initialContacts = initialContacts or {},
    contactsSearchInput = contactsSearchInput,
  }
  for key, value in pairs(extraOptions or {}) do
    options[key] = value
  end
  return ContactsRuntime.Create(factory, options)
end

-- Returns the text of the shown empty-state hint, or nil when it is hidden.
local function shownEmptyText(runtime)
  for _, child in ipairs(runtime.contactsController.content.children or {}) do
    if child.label and child:IsShown() then
      return child.label.text
    end
  end
  return nil
end

return function()
  -- test_whispers_tab_empty_no_search_shows_message
  do
    local factory = FakeUI.NewFactory()
    local runtime = makeRuntime(factory, {})

    assert(runtime.getTabMode() == "whispers", "default tab mode should be whispers")

    runtime.refreshContacts({}, nil, true)

    local found = false
    for _, child in ipairs(runtime.contactsController.content.children or {}) do
      if child.label and child.label.text == WHISPERS_EMPTY_MSG then
        found = true
        assert(child:IsShown() == true, "empty-state frame should be shown")
      end
    end
    assert(found, "expected an empty-state child with the whispers empty message")
  end

  -- test_whispers_tab_empty_results_with_search_text_stays_hidden
  do
    local factory = FakeUI.NewFactory()
    local searchInput = factory.CreateFrame("EditBox", nil, nil)
    searchInput:SetText("nomatch")
    local runtime = makeRuntime(factory, { makeItem(ChannelType.WHISPER) }, searchInput)

    runtime.refreshContacts(nil, nil, true)

    for _, child in ipairs(runtime.contactsController.content.children or {}) do
      if child.label then
        assert(child:IsShown() == false, "empty-state must stay hidden while search text is present")
      end
    end
  end

  -- test_whispers_tab_with_contacts_stays_hidden
  do
    local factory = FakeUI.NewFactory()
    local runtime = makeRuntime(factory, { makeItem(ChannelType.WHISPER) })

    runtime.refreshContacts(nil, nil, true)

    for _, child in ipairs(runtime.contactsController.content.children or {}) do
      if child.label then
        assert(child:IsShown() == false, "empty-state must stay hidden when contacts exist")
      end
    end
  end

  -- test_groups_tab_without_group_chats_shows_groups_message
  do
    local factory = FakeUI.NewFactory()
    local runtime = makeRuntime(factory, { makeItem(ChannelType.WHISPER) }, nil, { initialTabMode = "groups" })

    runtime.refreshContacts(nil, nil, true)

    assert(shownEmptyText(runtime) == GROUPS_EMPTY_MSG, "groups tab with no group chats shows the groups hint")
  end

  -- test_groups_tab_with_group_chats_stays_hidden
  do
    local factory = FakeUI.NewFactory()
    local runtime = makeRuntime(factory, { makeItem(ChannelType.PARTY), makeItem(ChannelType.WHISPER) }, nil, { initialTabMode = "groups" })

    runtime.refreshContacts(nil, nil, true)

    assert(shownEmptyText(runtime) == nil, "groups tab with group chats hides the hint")
  end

  -- test_whispers_tab_never_shows_groups_message
  do
    local factory = FakeUI.NewFactory()
    local runtime = makeRuntime(factory, { makeItem(ChannelType.PARTY) })

    runtime.refreshContacts(nil, nil, true)

    assert(shownEmptyText(runtime) == WHISPERS_EMPTY_MSG, "whispers tab with only group chats shows the whispers hint")
  end

  -- test_groups_tab_with_group_chats_turned_off_stays_hidden
  do
    local factory = FakeUI.NewFactory()
    local runtime = makeRuntime(factory, { makeItem(ChannelType.PARTY) }, nil, {
      initialTabMode = "groups",
      settingsConfig = { showGroupChats = false },
    })

    runtime.refreshContacts(nil, nil, true)

    assert(shownEmptyText(runtime) == nil, "no groups hint while group chats are turned off")
  end
end
