local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local ContactsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRuntime")
local Localization = require("WhisperMessenger.Locale.Localization")

-- The Channels tab appears while at least one channel is ticked, even with
-- group chats hidden, and lists only channel chats.

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

-- Creation order: Whispers, Groups, Requests, Channels.
local function channelsButton(runtime)
  return FindUI.ofType(runtime.tabToggle.frame, "Button")[4]
end

local ITEMS = {
  { conversationKey = "a", channel = "WOW", displayName = "Friend", unreadCount = 1, lastActivityAt = 2 },
  { conversationKey = "t", channel = "CHANNEL", displayName = "Trade", unreadCount = 3, inChannelsTab = true, lastActivityAt = 1 },
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

  -- test_channels_tab_shows_with_groups_off
  do
    local settings = { showGroupChats = false, enabledChannels = { trade = true } }
    local runtime = makeRuntime(settings)
    assert(runtime.tabToggle.frame.shown == true, "the footer shows for Whispers + Channels")
    assert(channelsButton(runtime).shown == true, "Channels tab visible")

    runtime.refreshContacts(ITEMS)
    assert(shownKeys(runtime) == "a", "Whispers lists only the friend, got " .. shownKeys(runtime))
    runtime.setTabMode("channels")
    assert(shownKeys(runtime) == "t", "Channels lists only the channel chat, got " .. shownKeys(runtime))

    -- test_unticking_every_channel_hides_the_tab
    settings.enabledChannels = { trade = false }
    runtime.refreshTabToggleVisibility()
    assert(channelsButton(runtime).shown == false, "Channels tab hidden")
    assert(runtime.tabToggle.frame.shown == false, "only Whispers left: footer hidden")
  end

  -- test_ticking_the_first_channel_shows_the_tab_without_reload
  do
    local settings = { enabledChannels = {} }
    local runtime = makeRuntime(settings)
    assert(channelsButton(runtime).shown == false, "nothing ticked: no Channels tab")
    settings.enabledChannels = { trade = true }
    runtime.refreshTabToggleVisibility()
    assert(channelsButton(runtime).shown == true, "first ticked channel shows the tab")
  end

  -- test_channels_tab_unread_badge
  do
    local runtime = makeRuntime({ enabledChannels = { trade = true } })
    runtime.refreshContacts(ITEMS)
    local badge = FindUI.ofType(channelsButton(runtime), "Frame")[1]
    assert(badge.shown ~= false, "Channels badge shows the channel chat's unread count")
  end

  -- test_empty_channels_tab_shows_a_hint
  do
    local runtime = makeRuntime({ enabledChannels = { trade = true } }, "channels")
    runtime.refreshContacts({ ITEMS[1] })
    assert(FindUI.text(runtime.contacts.content, "No channel messages yet.") ~= nil, "empty Channels tab explains itself")
  end

  -- test_saved_channels_mode_falls_back_when_nothing_ticked
  do
    local runtime = makeRuntime({ enabledChannels = {} }, "channels")
    assert(runtime.getTabMode() == "whispers", "a saved Channels tab opens on Whispers when no channel is ticked")
  end
end
