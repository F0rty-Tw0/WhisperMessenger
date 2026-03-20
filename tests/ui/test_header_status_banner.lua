local Availability = require("WhisperMessenger.Transport.Availability")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")
local StatusLine = require("WhisperMessenger.UI.ConversationPane.StatusLine")

return function()
  -- SetStatus should display the human-readable label, not the raw status key
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(600, 420)

  local pane = ConversationPane.Create(factory, parent, {
    displayName = "Arthas",
    className = "Hunter",
  }, { messages = {} })

  -- WrongFaction should display as "Wrong Faction", not "WrongFaction"
  ConversationPane.SetStatus(pane, Availability.FromStatus("WrongFaction"))
  local bannerText = pane.statusBanner.text or ""
  local expected = StatusLine.AVAILABILITY_DISPLAY["WrongFaction"].label
  assert(bannerText == expected, "status banner should show '" .. expected .. "', got: '" .. bannerText .. "'")

  -- Offline should display as "Offline"
  ConversationPane.SetStatus(pane, Availability.FromStatus("Offline"))
  bannerText = pane.statusBanner.text or ""
  assert(bannerText == "Offline", "status banner should show 'Offline', got: '" .. bannerText .. "'")

  -- CanWhisper should display as "Online"
  ConversationPane.SetStatus(pane, Availability.FromStatus("CanWhisper"))
  bannerText = pane.statusBanner.text or ""
  assert(bannerText == "Online", "status banner should show 'Online', got: '" .. bannerText .. "'")

  -- nil status should clear the banner
  ConversationPane.SetStatus(pane, nil)
  bannerText = pane.statusBanner.text or ""
  assert(bannerText == "", "status banner should be empty for nil status, got: '" .. bannerText .. "'")
end
