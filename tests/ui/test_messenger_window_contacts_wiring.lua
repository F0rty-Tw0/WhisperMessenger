-- Contacts wiring reaches the conversation pane and selection controller,
-- which are built after it, at call time.
local FakeUI = require("tests.helpers.fake_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local ContactsList = require("WhisperMessenger.UI.ContactsList")
local ContactsWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsWiring")
local Localization = require("WhisperMessenger.Locale.Localization")

local function makeWiring(late, windowOptions)
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)
  local pane = factory.CreateFrame("Frame", nil, frame)
  pane:SetSize(200, 400)
  local chrome = { markAllReadShown = nil }
  function chrome.setMarkAllReadShown(shown)
    chrome.markAllReadShown = shown
  end
  local layout = {
    contactsPane = pane,
    contactsView = ScrollView.Create(factory, pane, { width = 200, height = 400 }),
  }
  local runtime = ContactsWiring.Create(factory, {
    layout = layout,
    frame = frame,
    chrome = chrome,
    settingsConfig = {},
    windowGeometry = {
      isCollapsed = function()
        return false
      end,
    },
    windowOptions = windowOptions or {},
    getSelectionController = function()
      return late.selectionController
    end,
    getConversation = function()
      return late.conversation
    end,
    getSelectedConversationKey = function()
      return nil
    end,
  })
  return runtime, chrome, layout
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_tab_change_before_pane_and_controller_exist_is_safe
  do
    local runtime = makeWiring({})
    runtime.setTabMode("groups")
    assert(runtime.getTabMode() == "groups", "tab mode switched with nothing bound yet")
  end

  -- test_tab_change_retitles_the_late_bound_conversation_pane
  do
    local late, seenModes, savedModes = {}, {}, {}
    local runtime = makeWiring(late, {
      onTabModeChanged = function(mode)
        table.insert(savedModes, mode)
      end,
    })
    late.conversation = {
      headerEmpty = {
        setMode = function(mode)
          table.insert(seenModes, mode)
        end,
      },
    }
    runtime.setTabMode("groups")
    assert(seenModes[1] == "groups", "empty header follows the tab")
    assert(savedModes[1] == "groups", "window option still hears the tab change")
  end

  -- test_tab_swap_clears_selection_through_the_late_bound_controller
  do
    local late, refreshed = {}, {}
    local runtime = makeWiring(late)
    late.selectionController = {
      refresh = function(nextState)
        table.insert(refreshed, nextState)
      end,
      handleContactSelected = function() end,
    }
    runtime.setTabMode("groups")
    assert(#refreshed == 1 and next(refreshed[1]) == nil, "empty tab clears the selection")
  end

  -- test_unread_contacts_show_mark_all_read
  do
    local runtime, chrome = makeWiring({})
    local contacts = ContactsList.BuildItems({
      ["me::WOW::jaina"] = { displayName = "Jaina", channel = "WOW", lastActivityAt = 1, unreadCount = 2 },
    })
    runtime.refreshContacts(contacts, nil, true)
    assert(chrome.markAllReadShown == true, "unread contact shows the mark-all-read button")
  end
end
