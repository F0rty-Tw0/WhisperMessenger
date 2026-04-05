local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local RowScripts = require("WhisperMessenger.UI.ContactsList.RowScripts")
local ActionButtons = require("WhisperMessenger.UI.ContactsList.ActionButtons")

local function assertColorEquals(actual, expected, label)
  assert(type(actual) == "table", label .. ": missing actual color")
  for i = 1, 4 do
    local a = actual[i] or (i == 4 and 1) or 0
    local e = expected[i] or (i == 4 and 1) or 0
    assert(math.abs(a - e) < 0.0001, label .. ": channel " .. i .. " mismatch")
  end
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  local row = factory.CreateFrame("Button", nil, parent)
  row:SetSize(260, Theme.LAYOUT.CONTACT_ROW_HEIGHT)
  row.item = {
    conversationKey = "wow::test::target",
    displayName = "Target",
    channel = "WOW",
    pinned = false,
    unreadCount = 0,
  }
  row.selected = false
  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetAllPoints(row)

  RowScripts.bindHover(row, { rowBaseBg = Theme.COLORS.bg_secondary })

  local removeButton = ActionButtons.createRemoveButton(factory, row, 260, { onRemove = function() end })
  local pinButton = ActionButtons.createPinButton(factory, row, row.item, 260, { onPin = function() end })
  row.removeButton = removeButton
  row.pinButton = pinButton

  -- Simulate pointer moving from row into action button, then fully out.
  row.mouseOver = true
  row.scripts.OnEnter(row)
  row.mouseOver = false
  removeButton.mouseOver = true
  removeButton.scripts.OnEnter(removeButton)
  row.scripts.OnLeave(row)

  assertColorEquals(
    row.bg.color,
    Theme.COLORS.bg_contact_hover,
    "row should stay hover-colored while over action button"
  )

  removeButton.mouseOver = false
  row.mouseOver = false
  removeButton.scripts.OnLeave(removeButton)

  assertColorEquals(
    row.bg.color,
    Theme.COLORS.bg_secondary,
    "row should restore base color after leaving action button"
  )
  assert(row.removeButton:IsShown() == false, "remove button should hide after leaving row/actions")
  assert(row.pinButton:IsShown() == false, "pin button should hide after leaving row/actions")

  print("  Contacts row hover synchronization tests passed")
end
