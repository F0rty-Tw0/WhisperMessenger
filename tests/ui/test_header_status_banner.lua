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
  -- test_header_status_ellipsizes_when_narrow_and_restores_when_wide
  do
    local contact = {
      channel = "BN",
      bnetAccountID = 42,
      displayName = "LongBattleTag#1234",
      name = "Tyrande",
      realmName = "Moon Guard",
      className = "Demon Hunter",
      factionName = "Alliance",
    }
    local conversation = { messages = {} }
    local status = Availability.FromStatus("CanWhisper")
    local fullStatus = "Online  -  Tyrande-Moon Guard  -  Demon Hunter  -  Alliance"
    local narrowPrefix = "Online  -  Tyrande-Moon Guard"
    local responsivePane = ConversationPane.Create(factory, parent, contact, conversation)

    ConversationPane.Refresh(responsivePane, contact, conversation, status)
    ConversationPane.Relayout(responsivePane, 299, 420)

    local statusLabel = responsivePane.headerStatus
    assert(statusLabel.justifyH == "LEFT", "narrow status should be explicitly left justified, got: " .. tostring(statusLabel.justifyH))
    assert(
      string.sub(statusLabel:GetText(), 1, #narrowPrefix) == narrowPrefix,
      "narrow status should retain availability and character-realm prefix, got: " .. statusLabel:GetText()
    )
    assert(string.sub(statusLabel:GetText(), -3) == "...", "narrow status should end in ellipsis, got: " .. statusLabel:GetText())
    assert(statusLabel.wordWrap == false, "narrow status should not wrap")
    assert(statusLabel.maxLines == 1, "narrow status should remain on one line")
    assert(statusLabel:GetStringWidth() <= statusLabel:GetWidth(), "narrow status width should not exceed its label width")

    ConversationPane.Relayout(responsivePane, 900, 420)
    assert(statusLabel:GetText() == fullStatus, "wide relayout should restore the full status without refresh, got: " .. statusLabel:GetText())
  end
end
