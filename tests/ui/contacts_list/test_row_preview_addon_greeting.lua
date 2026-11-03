local RowElements = require("WhisperMessenger.UI.ContactsList.RowElements")
local RowTooltip = require("WhisperMessenger.UI.ContactsList.RowTooltip")
local FakeUI = require("tests.helpers.fake_ui")

-- A contact row whose last line is an addon-tagged whisper names CraftScan
-- Craft Alert, like the bubble; the stored preview keeps the received text.

local TEXT = "Found you via CraftScan: hi"
local SHOWN = "Found you via Craft Alert: hi"

local function taggedItem()
  local conversation = { messages = { { text = TEXT, direction = "in", kind = "user", addonGreeting = "CraftScan" } } }
  return { conversationKey = "wow::customer", displayName = "Customer", lastPreview = TEXT, conversation = conversation }
end

local function test_row_preview_names_craft_alert()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)
  local row = factory.CreateFrame("Frame", nil, parent)
  row.classIconFrame = factory.CreateFrame("Frame", nil, row)
  local item = taggedItem()
  RowElements.createPreview(row, item, 260)
  RowElements.updatePreview(row, item, 260, false)
  assert(row.preview.text == SHOWN, "row preview renamed, got " .. tostring(row.preview.text))
  assert(item.lastPreview == TEXT, "the stored preview stays as received")
end

local function test_rail_tooltip_names_craft_alert()
  local lines = RowTooltip.Lines(taggedItem(), false)
  local found = false
  for _, line in ipairs(lines) do
    found = found or line.text == SHOWN
  end
  assert(found, "tooltip last line renamed")
end

return function()
  test_row_preview_names_craft_alert()
  test_rail_tooltip_names_craft_alert()
end
