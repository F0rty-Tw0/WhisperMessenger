local FakeUI = require("tests.helpers.fake_ui")
local HeaderView = require("WhisperMessenger.UI.ConversationPane.HeaderView")
local Theme = require("WhisperMessenger.UI.Theme")

return function()
  local factory = FakeUI.NewFactory()
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(600, 420)

  -- test_badge_hidden_with_no_contact
  do
    local view = HeaderView.Create(factory, pane, nil)
    assert(view.headerAddonBadge ~= nil, "header should have an addon badge fontstring")
    HeaderView.Refresh(view, nil, nil, nil)
    assert(view.headerAddonBadge:IsShown() == false, "badge should be hidden with no contact")
  end

  -- test_badge_hidden_when_channel_not_wow_or_bn
  do
    local contact = { displayName = "Arthas", classTag = "HUNTER", factionName = "Horde", peerHasAddon = false }
    local view = HeaderView.Create(factory, pane, contact)
    HeaderView.Refresh(view, contact, nil, nil)
    assert(view.headerAddonBadge:IsShown() == false, "badge should be hidden for a non whisper channel")
  end

  -- test_badge_shown_with_peer_addon
  do
    local contact = { displayName = "Arthas", classTag = "HUNTER", factionName = "Horde", channel = "WOW", peerHasAddon = true }
    local view = HeaderView.Create(factory, pane, contact)
    HeaderView.Refresh(view, contact, nil, nil)
    assert(view.headerAddonBadge:IsShown() == true, "badge should show when peerHasAddon is true")
    assert(view.headerAddonBadge:GetText() == "(Uses WM)", "badge text should read '(Uses WM)', got: " .. tostring(view.headerAddonBadge:GetText()))
    local tc = view.headerAddonBadge.textColor
    local gold = Theme.TAG_GOLD
    assert(
      tc ~= nil and tc[1] == gold[1] and tc[2] == gold[2] and tc[3] == gold[3] and (tc[4] or 1) == (gold[4] or 1),
      "badge should be colored TAG_GOLD, got: " .. tostring(tc and tc[1])
    )
  end

  -- test_invite_hint_shown_for_wow_contact_without_addon
  do
    local contact = { displayName = "Arthas", classTag = "HUNTER", factionName = "Horde", channel = "WOW", peerHasAddon = false }
    local view = HeaderView.Create(factory, pane, contact)
    HeaderView.Refresh(view, contact, nil, nil)
    assert(view.headerAddonBadge:IsShown() == true, "invite hint should show for a WOW contact without the addon")
    assert(
      view.headerAddonBadge:GetText() == "(Invite to WM)",
      "badge text should read '(Invite to WM)', got: " .. tostring(view.headerAddonBadge:GetText())
    )
    local tc = view.headerAddonBadge.textColor
    local secondary = Theme.COLORS.text_secondary
    assert(
      tc ~= nil and tc[1] == secondary[1] and tc[2] == secondary[2] and tc[3] == secondary[3],
      "invite hint should be colored text_secondary, got: " .. tostring(tc and tc[1])
    )
  end

  -- test_invite_hint_shown_for_bn_contact_without_addon
  do
    local contact = { displayName = "Jaina", channel = "BN", peerHasAddon = false }
    local view = HeaderView.Create(factory, pane, contact)
    HeaderView.Refresh(view, contact, nil, nil)
    assert(view.headerAddonBadge:IsShown() == true, "invite hint should show for a BN contact without the addon")
    assert(
      view.headerAddonBadge:GetText() == "(Invite to WM)",
      "badge text should read '(Invite to WM)', got: " .. tostring(view.headerAddonBadge:GetText())
    )
  end

  -- test_badge_hidden_for_group_conversation
  do
    local contact = { displayName = "Raid Group", channel = "RAID", peerHasAddon = true }
    local view = HeaderView.Create(factory, pane, contact)
    HeaderView.Refresh(view, contact, nil, nil)
    assert(view.headerAddonBadge:IsShown() == false, "badge should be hidden for a group conversation")
  end

  -- test_status_detail_shows_line2_and_hides_when_empty
  do
    local contactWithArea = {
      displayName = "Nergrom",
      classTag = "HUNTER",
      factionName = "Horde",
      realmName = "Kazzak",
      areaName = "Voidscar Arena",
    }
    local view = HeaderView.Create(factory, pane, contactWithArea)
    HeaderView.Refresh(view, contactWithArea, nil, { status = "CanWhisper" })
    assert(view.headerStatusDetail ~= nil, "header should have a status detail fontstring")
    assert(view.headerStatusDetail:IsShown() == true, "status detail should show when line2 is non-empty")
    assert(
      string.find(view.headerStatusDetail:GetText(), "Voidscar Arena", 1, true) ~= nil,
      "status detail should contain the area name: " .. tostring(view.headerStatusDetail:GetText())
    )

    local bareContact = { displayName = "Nergrom", classTag = "HUNTER" }
    HeaderView.Refresh(view, bareContact, nil, nil)
    assert(view.headerStatusDetail:IsShown() == false, "status detail should hide when line2 is empty")
  end
end
