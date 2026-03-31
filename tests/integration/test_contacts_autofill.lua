local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

  -- Create 20 contacts so there are more than the initial visible count
  local contacts = {}
  for i = 1, 20 do
    contacts[i] = {
      conversationKey = "player" .. i,
      displayName = "Player" .. i,
      channel = "WHISPER",
      preview = "hello",
      timestamp = 1000 + i,
    }
  end

  local window = MessengerWindow.Create(factory, {
    contacts = contacts,
  })

  -- Initial visible count should be based on viewport, not hardcoded 10
  local contactsH = Theme.WINDOW_HEIGHT - Theme.TOP_BAR_HEIGHT
  local rowH = Theme.LAYOUT.CONTACT_ROW_HEIGHT
  local searchTotalHeight = (Theme.LAYOUT.CONTACT_SEARCH_HEIGHT or 30)
    + ((Theme.LAYOUT.CONTACT_SEARCH_MARGIN or 10) * 2)
  local contactsListH = math.max(0, contactsH - searchTotalHeight)
  local expectedInitial = math.ceil(contactsListH / rowH) + 1
  if expectedInitial > 20 then
    expectedInitial = 20
  end
  local visibleRows = 0
  for _, row in ipairs(window.contacts.rows) do
    if row.item ~= nil then
      visibleRows = visibleRows + 1
    end
  end
  assert(
    visibleRows >= expectedInitial,
    "expected at least " .. expectedInitial .. " visible contacts but got " .. visibleRows
  )

  -- Resize to a taller window and verify more contacts load
  local tallHeight = 1200
  window.frame:SetSize(Theme.WINDOW_WIDTH, tallHeight)
  window.frame.scripts.OnSizeChanged(window.frame, Theme.WINDOW_WIDTH, tallHeight)

  local tallContactsH = tallHeight - Theme.TOP_BAR_HEIGHT
  local tallContactsListH = math.max(0, tallContactsH - searchTotalHeight)
  local expectedTall = math.ceil(tallContactsListH / rowH) + 1
  if expectedTall > 20 then
    expectedTall = 20
  end
  local visibleAfterResize = 0
  for _, row in ipairs(window.contacts.rows) do
    if row.item ~= nil then
      visibleAfterResize = visibleAfterResize + 1
    end
  end
  assert(
    visibleAfterResize >= expectedTall,
    "expected at least " .. expectedTall .. " visible contacts after resize but got " .. visibleAfterResize
  )

  _G.UIParent = savedUIParent
end
