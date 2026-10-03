local FakeUI = require("tests.helpers.fake_ui")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local ContactsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRuntime")

local function makeRuntime(factory, initialContacts, searchInput, onSearchAvailableChanged)
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(200, 400)
  return ContactsRuntime.Create(factory, {
    contactsView = ScrollView.Create(factory, parent, { width = 200, height = 400 }),
    initialContacts = initialContacts,
    contactsSearchInput = searchInput,
    onSearchAvailableChanged = onSearchAvailableChanged,
  })
end

local function whisper()
  return { channel = ChannelType.WHISPER, displayName = "test", conversationKey = "k-whisper" }
end

return function()
  -- test_search_unavailable_on_a_tab_with_no_chats
  do
    local available = nil
    local runtime = makeRuntime(FakeUI.NewFactory(), {}, nil, function(value)
      available = value
    end)
    runtime.refreshContacts({}, nil, true)
    assert(available == false, "nothing to search on an empty tab")
  end

  -- test_search_available_when_the_tab_has_chats
  do
    local available = nil
    local runtime = makeRuntime(FakeUI.NewFactory(), { whisper() }, nil, function(value)
      available = value
    end)
    runtime.refreshContacts(nil, nil, true)
    assert(available == true, "a tab with chats can be searched")
  end

  -- test_search_stays_available_while_it_has_text
  do
    -- A query with no matches must leave the box up so it can be cleared.
    local factory = FakeUI.NewFactory()
    local searchInput = factory.CreateFrame("EditBox", nil, nil)
    searchInput:SetText("nomatch")
    local available = nil
    local runtime = makeRuntime(factory, {}, searchInput, function(value)
      available = value
    end)
    runtime.refreshContacts({}, nil, true)
    assert(available == true, "search with text stays available on an empty result")
  end
end
