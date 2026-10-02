local FakeUI = require("tests.helpers.fake_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local ContactsList = require("WhisperMessenger.UI.ContactsList")
local ContactsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRuntime")
local Localization = require("WhisperMessenger.Locale.Localization")

-- While the contacts pane is the collapsed rail the runtime binds icon-only
-- rows, hides the empty-state hint and hangs the footer tabs below the window.

local function makeRuntime(contacts, isCompact)
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  local pane = factory.CreateFrame("Frame", nil, window)
  pane:SetSize(46, 400)
  local contactsView = ScrollView.Create(factory, pane, { width = 46, height = 400 })
  local runtime = ContactsRuntime.Create(factory, {
    contactsPane = pane,
    windowFrame = window,
    contactsView = contactsView,
    initialContacts = contacts,
    settingsConfig = { requestsInbox = true },
    isCompact = isCompact,
  })
  return runtime, window
end

local function compact()
  return true
end

return function()
  Localization.Configure({ language = "enUS" })
  local contacts = ContactsList.BuildItems({
    ["me::WOW::jaina"] = { displayName = "Jaina", channel = "WOW", lastActivityAt = 1, unreadCount = 0 },
  })

  -- test_collapsed_runtime_binds_icon_only_rows
  do
    local runtime = makeRuntime(contacts, compact)
    runtime.refreshContacts(contacts, nil, true)
    assert(runtime.contacts.rows[1]._wmCompact == true, "rows bind compact while collapsed")
  end

  -- test_expanded_runtime_binds_full_rows
  do
    local runtime = makeRuntime(contacts, nil)
    runtime.refreshContacts(contacts, nil, true)
    assert(runtime.contacts.rows[1]._wmCompact == false, "rows bind full while expanded")
  end

  -- test_collapsed_runtime_hides_the_empty_state_hint
  do
    local runtime = makeRuntime({}, compact)
    runtime.refreshContacts({}, nil, true)
    local hint = runtime.contactsController.content.children[#runtime.contactsController.content.children]
    assert(hint.label ~= nil, "found the empty-state frame")
    assert(hint.shown ~= true, "no empty-state text in the rail")
  end

  -- test_tabs_hang_from_the_window_in_the_rail
  do
    local runtime, window = makeRuntime(contacts, compact)
    local _, relativeTo = table.unpack(runtime.tabToggle.frame.points[1])
    assert(relativeTo == window, "tabs hang from the window")
  end
end
