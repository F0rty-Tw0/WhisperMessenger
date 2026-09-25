local ContactsList = require("WhisperMessenger.UI.ContactsList")
local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")

-- Right-clicking a contact row hands the window's onUpdatePrefs callback to
-- the context menu, so Mute / nickname / note reach the runtime.
return function()
  local conversations = {
    ["me::WOW::arthas"] = { displayName = "Arthas", lastActivityAt = 1, messages = {} },
  }
  local received
  local window = MessengerWindow.Create(FakeUI.NewFactory(), {
    contacts = ContactsList.BuildItems(conversations),
    onUpdatePrefs = function(item, changes)
      received = { item = item, changes = changes }
    end,
  })

  local passedCallback
  local originalOpen = ContextMenu.Open
  rawset(ContextMenu, "Open", function(_item, _anchor, _onMarkUnread, onUpdatePrefs)
    passedCallback = onUpdatePrefs
    return true
  end)
  local row = window.contacts.rows[1]
  row.scripts.OnClick(row, "RightButton")
  rawset(ContextMenu, "Open", originalOpen)

  -- test_row_menu_receives_the_prefs_callback
  assert(type(passedCallback) == "function", "row right-click passes an onUpdatePrefs callback")
  passedCallback(row.item, { muted = true })
  assert(received and received.item == row.item and received.changes.muted == true, "callback reaches the window option")
end
