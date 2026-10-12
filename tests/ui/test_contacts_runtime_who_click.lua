local FakeUI = require("tests.helpers.fake_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local ContactsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRuntime")

-- A contact row click reports the clicked item before selecting it, so the
-- /who lookup runs inside the click.

local function makeRuntime(calls, whoPlayer)
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  local pane = factory.CreateFrame("Frame", nil, window)
  pane:SetSize(200, 400)
  local contactsView = ScrollView.Create(factory, pane, { width = 200, height = 400 })
  return ContactsRuntime.Create(factory, {
    contactsPane = pane,
    contactsView = contactsView,
    settingsConfig = {},
    whoPlayer = whoPlayer,
    onContactClicked = function(item)
      calls[#calls + 1] = { name = "clicked", item = item }
    end,
    onSelect = function(item)
      calls[#calls + 1] = { name = "select", item = item }
    end,
  })
end

local ITEMS = {
  { conversationKey = "a", channel = "WOW", displayName = "Friend", unreadCount = 0, lastActivityAt = 2 },
}

local function rowFor(runtime, key)
  for _, row in ipairs(runtime.contacts.rows) do
    if row.item and row.item.conversationKey == key then
      return row
    end
  end
  return nil
end

return function()
  -- test_row_click_reports_contact_clicked_before_select
  do
    local calls = {}
    local runtime = makeRuntime(calls)
    runtime.refreshContacts(ITEMS)
    local row = rowFor(runtime, "a")
    assert(row ~= nil, "row for the contact")
    row.scripts.OnClick(row, "LeftButton")
    assert(#calls == 2, "clicked and select both called, got " .. #calls)
    assert(calls[1].name == "clicked" and calls[1].item.conversationKey == "a", "clicked first with the item")
    assert(calls[2].name == "select" and calls[2].item.conversationKey == "a", "then select")
  end

  -- test_who_player_reaches_row_options
  do
    local calls = {}
    local whoNames = {}
    local runtime = makeRuntime(calls, function(name)
      whoNames[#whoNames + 1] = name
      return true
    end)
    runtime.refreshContacts(ITEMS)
    local row = rowFor(runtime, "a")
    local originalShift = _G.IsShiftKeyDown
    _G.IsShiftKeyDown = function()
      return true
    end
    row.scripts.OnClick(row, "LeftButton")
    _G.IsShiftKeyDown = originalShift
    assert(#whoNames == 1 and whoNames[1] == "Friend", "whoPlayer threaded to the row click")
    assert(#calls == 0, "shift-click selects nothing and reports no contact click")
  end
end
