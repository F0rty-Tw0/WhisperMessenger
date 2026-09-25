local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local ContactsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRuntime")
local Localization = require("WhisperMessenger.Locale.Localization")

-- The Requests tab appears only while the Requests inbox is on, even with
-- group chats hidden, and lists only requests.

local function makeRuntime(settingsConfig, initialTabMode)
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  local pane = factory.CreateFrame("Frame", nil, window)
  pane:SetSize(200, 400)
  local contactsView = ScrollView.Create(factory, pane, { width = 200, height = 400 })
  return ContactsRuntime.Create(factory, {
    contactsPane = pane,
    contactsView = contactsView,
    settingsConfig = settingsConfig,
    initialTabMode = initialTabMode,
  })
end

local function requestsButton(runtime)
  return FindUI.ofType(runtime.tabToggle.frame, "Button")[3]
end

local ITEMS = {
  { conversationKey = "a", channel = "WOW", displayName = "Friend", unreadCount = 1, lastActivityAt = 2 },
  { conversationKey = "b", channel = "WOW", displayName = "Stranger", unreadCount = 3, isRequest = true, lastActivityAt = 1 },
}

local function shownKeys(runtime)
  local keys = {}
  for _, row in ipairs(runtime.contacts.rows) do
    if row.item and row.shown ~= false then
      keys[#keys + 1] = row.item.conversationKey
    end
  end
  return table.concat(keys, ",")
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_requests_tab_shows_with_groups_off
  do
    local settings = { showGroupChats = false, requestsInbox = true }
    local runtime = makeRuntime(settings)
    assert(runtime.tabToggle.frame.shown == true, "the footer shows for Whispers + Requests")
    assert(requestsButton(runtime).shown == true, "Requests tab visible")
    assert(FindUI.ofType(runtime.tabToggle.frame, "Button")[2].shown == false, "Groups tab hidden with group chats off")

    runtime.refreshContacts(ITEMS)
    assert(shownKeys(runtime) == "a", "Whispers lists only the friend, got " .. shownKeys(runtime))
    runtime.setTabMode("requests")
    assert(shownKeys(runtime) == "b", "Requests lists only the stranger, got " .. shownKeys(runtime))

    -- test_turning_inbox_off_hides_the_tab
    settings.requestsInbox = false
    runtime.refreshTabToggleVisibility()
    assert(requestsButton(runtime).shown == false, "Requests tab hidden")
    assert(runtime.tabToggle.frame.shown == false, "only Whispers left: footer hidden")
  end

  -- test_default_settings_keep_two_tabs
  do
    local runtime = makeRuntime({})
    assert(requestsButton(runtime).shown == false, "inbox off by default: no Requests tab")
    assert(runtime.tabToggle.frame.shown == true, "Whispers/Groups footer as before")
  end

  -- test_saved_requests_mode_falls_back_when_inbox_off
  do
    local runtime = makeRuntime({}, "requests")
    assert(runtime.getTabMode() == "whispers", "a saved Requests tab opens on Whispers when the inbox is off")
  end
end
