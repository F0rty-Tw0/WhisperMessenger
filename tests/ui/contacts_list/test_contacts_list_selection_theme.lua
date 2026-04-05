local ContactsList = require("WhisperMessenger.UI.ContactsList")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local function colorsMatch(actual, expected)
  if type(actual) ~= "table" or type(expected) ~= "table" then
    return false
  end
  local epsilon = 0.0001
  for i = 1, 4 do
    local a = actual[i] or (i == 4 and 1 or nil)
    local b = expected[i] or (i == 4 and 1 or nil)
    if a == nil or b == nil or math.abs(a - b) > epsilon then
      return false
    end
  end
  return true
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)

  local items = {
    {
      conversationKey = "me::WOW::alice",
      displayName = "Alice",
      lastPreview = "Hello there",
      unreadCount = 0,
      lastActivityAt = 100,
      channel = "WOW",
      classTag = nil,
      pinned = false,
    },
    {
      conversationKey = "me::WOW::bob",
      displayName = "Bob",
      lastPreview = "Ping",
      unreadCount = 0,
      lastActivityAt = 80,
      channel = "WOW",
      classTag = nil,
      pinned = false,
    },
  }

  local previousPreset = Theme.GetPreset and Theme.GetPreset() or nil
  if Theme.SetPreset then
    Theme.SetPreset("wow_default")
  end

  local rows = ContactsList.Refresh(factory, parent, {}, items, {
    selectedConversationKey = items[1].conversationKey,
    visibleCount = 2,
    onSelect = function() end,
    onPin = function() end,
    onRemove = function() end,
  })

  local selectedRow = rows[1]
  local unselectedRow = rows[2]

  assert(selectedRow ~= nil and selectedRow.selected == true, "expected first row selected")
  assert(
    colorsMatch(selectedRow.accentBar.color, Theme.COLORS.accent_bar),
    "expected selected accent bar to use accent_bar"
  )
  assert(
    selectedRow.selectedRightBorder ~= nil and selectedRow.selectedRightBorder.shown ~= false,
    "expected selected right border to be shown"
  )
  assert(
    colorsMatch(selectedRow.selectedRightBorder.color, Theme.COLORS.contact_selected_border_right),
    "expected selected right border to use contact_selected_border_right"
  )
  assert(
    colorsMatch(selectedRow.preview.textColor, Theme.COLORS.text_primary),
    "expected selected preview text to use text_primary"
  )
  assert(
    colorsMatch(unselectedRow.preview.textColor, Theme.COLORS.text_secondary),
    "expected unselected preview text to use text_secondary"
  )

  if Theme.SetPreset then
    Theme.SetPreset("plumber_warm")
  end
  ContactsList.SetSelected(rows, items[1].conversationKey)

  assert(
    colorsMatch(selectedRow.accentBar.color, Theme.COLORS.accent_bar),
    "expected selected accent bar to repaint on preset switch"
  )
  assert(
    colorsMatch(selectedRow.selectedRightBorder.color, Theme.COLORS.contact_selected_border_right),
    "expected selected right border to repaint on preset switch"
  )
  assert(
    colorsMatch(selectedRow.preview.textColor, Theme.COLORS.text_primary),
    "expected selected preview text to repaint on preset switch"
  )

  ContactsList.SetSelected(rows, nil)
  assert(selectedRow.selectedRightBorder.shown == false, "expected selected right border to hide when selection clears")
  assert(
    colorsMatch(selectedRow.preview.textColor, Theme.COLORS.text_secondary),
    "expected preview text to restore when selection clears"
  )

  -- Re-applying selection while hovering another row should not hide that row's actions.
  unselectedRow.mouseOver = true
  unselectedRow.scripts.OnEnter(unselectedRow)
  assert(unselectedRow.removeButton:IsShown() == true, "expected hovered unselected row remove action to be shown")
  assert(unselectedRow.pinButton:IsShown() == true, "expected hovered unselected row pin action to be shown")

  ContactsList.SetSelected(rows, items[1].conversationKey)

  assert(
    unselectedRow.removeButton:IsShown() == true,
    "expected hovered unselected row remove action to remain shown after selection refresh"
  )
  assert(
    unselectedRow.pinButton:IsShown() == true,
    "expected hovered unselected row pin action to remain shown after selection refresh"
  )

  if Theme.SetPreset and previousPreset then
    Theme.SetPreset(previousPreset)
  end

  print("PASS: test_contacts_list_selection_theme")
end
