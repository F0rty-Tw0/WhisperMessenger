local ContactsList = require("WhisperMessenger.UI.ContactsList")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

  local contacts = ContactsList.BuildItems({
    ["me::WOW::jaina-proudmoore"] = {
      displayName = "Jaina-Proudmoore",
      lastPreview = "Need assistance?",
      unreadCount = 1,
      lastActivityAt = 20,
      channel = "WOW",
      messages = {
        { text = "Meet me in Stormwind Keep", playerName = "Jaina" },
      },
    },
    ["me::WOW::anduin-stormrage"] = {
      displayName = "Anduin-Stormrage",
      lastPreview = "On my way.",
      unreadCount = 0,
      lastActivityAt = 10,
      channel = "WOW",
      messages = {
        { text = "Heading to Ironforge now", playerName = "Anduin" },
      },
    },
  })

  local window = MessengerWindow.Create(factory, {
    title = "WhisperMessenger",
    contacts = contacts,
  })

  assert(window.contactsSearchInput ~= nil, "expected contacts search input")
  assert(window.contactsSearchClearButton ~= nil, "expected contacts search clear button")
  assert(#window.contacts.rows == 2, "precondition: expected full contacts list")
  assert(window.contactsSearchClearButton:IsShown() == false, "clear button should be hidden with empty search")

  local searchFrame = window.contactsSearchInput.parent
  assert(searchFrame ~= nil, "search input should be attached to a search frame")
  local regions = { searchFrame:GetRegions() }
  local textureCount = 0
  for _, region in ipairs(regions) do
    if region.frameType == "Texture" then
      textureCount = textureCount + 1
    end
  end
  assert(textureCount >= 5, "search frame should include background plus border textures for visual separation")

  -- Search by character/contact name.
  window.contactsSearchInput:SetText("anduin")
  window.contactsSearchInput.scripts.OnTextChanged(window.contactsSearchInput)
  assert(window.contacts.content.visibleCount == 1, "search by name should narrow contacts to one result")
  assert(window.contacts.rows[1].item.displayName == "Anduin-Stormrage", "name search should match Anduin conversation")
  assert(window.contactsSearchClearButton:IsShown() == true, "clear button should show while search is active")

  -- Search by message keyword across chat history.
  window.contactsSearchInput:SetText("stormwind")
  window.contactsSearchInput.scripts.OnTextChanged(window.contactsSearchInput)
  assert(window.contacts.content.visibleCount == 1, "search by message keyword should narrow contacts")
  assert(
    window.contacts.rows[1].item.displayName == "Jaina-Proudmoore",
    "keyword search should match Jaina conversation"
  )

  -- Clear via the X button and verify full list restoration.
  window.contactsSearchClearButton.scripts.OnClick(window.contactsSearchClearButton)
  assert(window.contactsSearchInput:GetText() == "", "clear button should empty the search input")
  assert(window.contacts.content.visibleCount == 2, "clearing search should restore all contacts")
  assert(window.contactsSearchClearButton:IsShown() == false, "clear button should hide after clearing")

  _G.UIParent = savedUIParent
end
