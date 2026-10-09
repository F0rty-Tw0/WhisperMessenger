local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local ContactsList = require("WhisperMessenger.UI.ContactsList")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local FakeUI = require("tests.helpers.fake_ui")

-- Only a real row click reports a contact click (the /who trigger); tab
-- restore and programmatic selection must not, since they run outside a
-- hardware event.

local JAINA = "me::WOW::jaina"

local function contacts()
  return ContactsList.BuildItems({
    [JAINA] = { displayName = "Jaina", channel = "WOW", lastActivityAt = 2, unreadCount = 1 },
    ["guild::me"] = { displayName = "Guild", channel = "GUILD", lastActivityAt = 1, unreadCount = 0 },
  })
end

local function build(onContactClicked)
  Hud.Configure("off")
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1920, 1080)
  local window = MessengerWindow.Create(factory, {
    contacts = contacts(),
    settingsConfig = { showGroupChats = true },
    onContactClicked = onContactClicked,
  })
  _G.UIParent = savedUIParent
  return window
end

local function rowFor(window, key)
  for _, row in ipairs(window.contacts.rows) do
    if row.item and row.item.conversationKey == key then
      return row
    end
  end
  return nil
end

return function()
  local clicked = {}
  local window = build(function(item)
    clicked[#clicked + 1] = item
  end)

  -- test_row_click_reports_contact_clicked
  local row = rowFor(window, JAINA)
  assert(row ~= nil, "Jaina row shown")
  row.scripts.OnClick(row, "LeftButton")
  assert(#clicked == 1 and clicked[1].conversationKey == JAINA, "row click reports Jaina")

  -- test_tab_restore_and_programmatic_select_do_not_report_click
  clicked = {}
  window.setTabMode("groups")
  window.setTabMode("whispers")
  window.selectConversation(JAINA)
  assert(#clicked == 0, "no click reported without a hardware event, got " .. #clicked)
end
