local FakeUI = require("tests.helpers.fake_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")
local ContactsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRuntime")
local Localization = require("WhisperMessenger.Locale.Localization")

-- The contacts list leaves room for a wrapped (two-row) footer on a narrow
-- pane, measured at the pane width the layout is about to apply.

local function makeRuntime(nativeChrome)
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  local pane = factory.CreateFrame("Frame", nil, window)
  pane:SetSize(300, 400)
  local contactsView = ScrollView.Create(factory, pane, { width = 300, height = 400 })
  return ContactsRuntime.Create(factory, {
    contactsPane = pane,
    contactsView = contactsView,
    nativeChrome = nativeChrome,
    settingsConfig = { requestsInbox = true },
  })
end

return function()
  Localization.Configure({ language = "enUS" })

  for _, nativeChrome in ipairs({ false, true }) do
    local skin = nativeChrome and "native" or "modern"
    local rowHeight = nativeChrome and TabToggle.NATIVE_HEIGHT or TabToggle.HEIGHT
    local runtime = makeRuntime(nativeChrome)

    -- test_narrow_pane_reserves_two_footer_rows
    assert(runtime.getContactsBottomInset(210) == 2 * rowHeight, skin .. ": narrow pane reserves two rows")

    -- test_wide_pane_reserves_one_footer_row
    assert(runtime.getContactsBottomInset(600) == rowHeight, skin .. ": wide pane reserves one row")
  end
end
