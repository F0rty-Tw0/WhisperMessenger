local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")
local Localization = require("WhisperMessenger.Locale.Localization")

-- A narrow contacts pane wraps the three footer tabs to two rows; the list
-- must stop above both rows, including after a language switch widens a label.

local function bottomAnchorY(scrollFrame)
  for i = #(scrollFrame.points or {}), 1, -1 do
    local pt = scrollFrame.points[i]
    if pt[1] == "BOTTOMRIGHT" then
      return pt[5]
    end
  end
  return nil
end

local function buildWindow(contactsWidth)
  local factory = FakeUI.NewFactory()
  return MessengerWindow.Create(factory, {
    contacts = {},
    state = { contactsWidth = contactsWidth },
    settingsConfig = { showGroupChats = true, requestsInbox = true },
  })
end

return function()
  local savedUIParent = _G.UIParent
  _G.UIParent = FakeUI.NewFactory().CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1280, 720)
  Localization.Configure({ language = "enUS" })

  -- test_narrow_pane_list_stops_above_both_footer_rows
  do
    local window = buildWindow(210)
    local listBottom = bottomAnchorY(window.contacts.scrollFrame)
    assert(listBottom == 2 * TabToggle.HEIGHT, "narrow pane: list stops above two rows, got " .. tostring(listBottom))
  end

  -- test_wide_pane_list_stops_above_one_footer_row
  do
    local window = buildWindow(300)
    local listBottom = bottomAnchorY(window.contacts.scrollFrame)
    assert(listBottom == TabToggle.HEIGHT, "wide pane: list stops above one row, got " .. tostring(listBottom))
  end

  -- test_longer_labels_after_language_switch_wrap_the_footer
  do
    local window = buildWindow(270)
    assert(bottomAnchorY(window.contacts.scrollFrame) == TabToggle.HEIGHT, "English labels fit one row at 270px")
    Localization.Configure({ language = "esES" })
    window.refreshLanguage("esES")
    local listBottom = bottomAnchorY(window.contacts.scrollFrame)
    assert(listBottom == 2 * TabToggle.HEIGHT, "Spanish 'Solicitudes' wraps at 270px, got " .. tostring(listBottom))
    Localization.Configure({ language = "enUS" })
  end

  _G.UIParent = savedUIParent
end
