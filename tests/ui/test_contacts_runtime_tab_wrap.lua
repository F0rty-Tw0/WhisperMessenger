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

  do
    local runtime = makeRuntime(false)

    -- test_narrow_pane_reserves_two_footer_rows
    assert(runtime.getContactsBottomInset(210) == 2 * TabToggle.HEIGHT, "modern: narrow pane reserves two rows")

    -- test_wide_pane_reserves_one_footer_row
    assert(runtime.getContactsBottomInset(600) == TabToggle.HEIGHT, "modern: wide pane reserves one row")
  end

  -- test_hud_tabs_hang_outside_so_reserve_nothing
  do
    local runtime = makeRuntime(true)
    assert(runtime.getContactsBottomInset(210) == 0, "native: narrow pane reserves nothing")
    assert(runtime.getContactsBottomInset(600) == 0, "native: wide pane reserves nothing")
  end
end
