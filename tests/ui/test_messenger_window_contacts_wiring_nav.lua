local FakeUI = require("tests.helpers.fake_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local ContactsWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsWiring")
local Localization = require("WhisperMessenger.Locale.Localization")

local function makeWiring(onNavTargetsChanged)
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)
  local pane = factory.CreateFrame("Frame", nil, frame)
  pane:SetSize(200, 400)
  local layout = { contactsPane = pane, contactsView = ScrollView.Create(factory, pane, { width = 200, height = 400 }) }
  return ContactsWiring.Create(factory, {
    layout = layout,
    frame = frame,
    chrome = { setMarkAllReadShown = function() end },
    settingsConfig = {},
    windowGeometry = {
      isCollapsed = function()
        return false
      end,
    },
    windowOptions = {},
    getSelectionController = function()
      return nil
    end,
    getConversation = function()
      return nil
    end,
    getSelectedConversationKey = function()
      return nil
    end,
    onNavTargetsChanged = onNavTargetsChanged,
  })
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_contacts_refresh_reports_nav_targets_changed
  do
    local count = 0
    local runtime = makeWiring(function()
      count = count + 1
    end)
    local before = count
    runtime.refreshContacts({ { conversationKey = "me::WOW::arthas", channel = "WOW", displayName = "Arthas", unreadCount = 0, lastActivityAt = 1 } })
    assert(count > before, "a contacts refresh asks for a re-scan")
  end

  -- test_contacts_refresh_without_the_callback_still_works
  do
    local runtime = makeWiring(nil)
    runtime.refreshContacts({})
  end
end
