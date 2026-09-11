local FakeUI = require("tests.helpers.fake_ui")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local ContactsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRuntime")

local WHISPERS_EMPTY_MSG = "No conversations yet. Click Start New Whisper to message a friend."

local function makeItem(channel)
  return { channel = channel, displayName = "test", conversationKey = "k-" .. tostring(channel) }
end

local function makeRuntime(factory, initialContacts, contactsSearchInput)
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(200, 400)
  local contactsView = ScrollView.Create(factory, parent, { width = 200, height = 400 })

  return ContactsRuntime.Create(factory, {
    contactsView = contactsView,
    initialContacts = initialContacts or {},
    contactsSearchInput = contactsSearchInput,
  })
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
end
