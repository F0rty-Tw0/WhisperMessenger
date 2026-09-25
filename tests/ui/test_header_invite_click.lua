local FakeUI = require("tests.helpers.fake_ui")
local HeaderView = require("WhisperMessenger.UI.ConversationPane.HeaderView")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local Theme = require("WhisperMessenger.UI.Theme")

local function clickBadge(view)
  local button = view.headerAddonBadgeButton
  assert(button ~= nil, "header should expose a clickable addon badge button")
  local handler = button:GetScript("OnClick")
  assert(type(handler) == "function", "addon badge button should have an OnClick script")
  handler(button, "LeftButton")
end

return function()
  local factory = FakeUI.NewFactory()
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(600, 420)

  -- test_invite_hint_click_invites_selected_contact
  do
    local contact = { displayName = "Arthas", channel = "WOW", peerHasAddon = false }
    local view = HeaderView.Create(factory, pane, contact)
    local invited = {}
    view.onInviteContact = function(target)
      table.insert(invited, target)
    end
    HeaderView.Refresh(view, contact, nil, nil)

    clickBadge(view)
    assert(#invited == 1 and invited[1] == contact, "clicking the invite hint should invite the selected contact")
  end

  -- test_invite_hint_enables_mouse_only_in_invite_mode
  do
    local contact = { displayName = "Arthas", channel = "WOW", peerHasAddon = false }
    local view = HeaderView.Create(factory, pane, contact)
    HeaderView.Refresh(view, contact, nil, nil)
    assert(view.headerAddonBadgeButton.mouseEnabled == true, "invite hint should accept mouse input")

    local addonContact = { displayName = "Arthas", channel = "WOW", peerHasAddon = true }
    HeaderView.Refresh(view, addonContact, nil, nil)
    assert(view.headerAddonBadgeButton.mouseEnabled == false, "the '(Uses WM)' badge should not accept mouse input")
  end

  -- test_sent_invite_shows_invite_sent_label
  do
    local contact = { displayName = "Arthas", channel = "WOW", peerHasAddon = false }
    local view = HeaderView.Create(factory, pane, contact)
    HeaderView.Refresh(view, contact, { inviteSent = true }, nil)
    assert(view.headerAddonBadge:IsShown() == true, "a sent invite should keep the badge visible")
    assert(
      view.headerAddonBadge:GetText() == "(Invite sent)",
      "badge text should read '(Invite sent)', got: " .. tostring(view.headerAddonBadge:GetText())
    )
    -- test_sent_invite_stays_dimmed
    local tc = view.headerAddonBadge.textColor
    assert(tc ~= nil and tc[1] == Theme.COLORS.text_secondary[1], "sent invite stays text_secondary")
  end

  -- test_sent_invite_is_not_clickable
  do
    local contact = { displayName = "Arthas", channel = "WOW", peerHasAddon = false }
    local view = HeaderView.Create(factory, pane, contact)
    local invites = 0
    view.onInviteContact = function()
      invites = invites + 1
    end
    HeaderView.Refresh(view, contact, { inviteSent = true }, nil)

    clickBadge(view)
    assert(invites == 0, "a conversation that already got an invite must not send another")
    assert(view.headerAddonBadgeButton.mouseEnabled == false, "a sent invite should not accept mouse input")
  end

  -- test_addon_peer_badge_is_not_clickable
  do
    local contact = { displayName = "Arthas", channel = "WOW", peerHasAddon = true }
    local view = HeaderView.Create(factory, pane, contact)
    local invites = 0
    view.onInviteContact = function()
      invites = invites + 1
    end
    HeaderView.Refresh(view, contact, nil, nil)

    clickBadge(view)
    assert(invites == 0, "a contact already running the addon must not be invited")
  end

  -- test_invite_sent_label_follows_language_refresh
  do
    local contact = { displayName = "Arthas", channel = "WOW", peerHasAddon = false }
    local view = HeaderView.Create(factory, pane, contact)
    HeaderView.Refresh(view, contact, { inviteSent = true }, nil)
    HeaderView.SetLanguage(view)
    assert(view.headerAddonBadge:GetText() == "(Invite sent)", "language refresh should keep the sent-invite label")

    HeaderView.Refresh(view, contact, nil, nil)
    HeaderView.SetLanguage(view)
    assert(view.headerAddonBadge:GetText() == "(Invite to WM)", "language refresh should keep the invite hint label")
  end

  -- test_conversation_pane_routes_the_invite_click_to_its_option
  do
    local paneParent = factory.CreateFrame("Frame", "InvitePaneParent", nil)
    paneParent:SetSize(600, 420)
    local contact = { displayName = "Arthas", conversationKey = "wow::WOW::arthas", channel = "WOW", peerHasAddon = false }
    local invited = {}
    local view = ConversationPane.Create(factory, paneParent, contact, { messages = {} }, {
      onInviteContact = function(target)
        table.insert(invited, target)
      end,
    })

    clickBadge(view)
    assert(#invited == 1 and invited[1] == contact, "the pane should route an invite click to its onInviteContact option")
  end

  -- test_tooltip_shows_only_while_the_invite_hint_is_clickable
  do
    local savedTooltip = _G.GameTooltip
    local tooltipText = nil
    rawset(_G, "GameTooltip", {
      SetOwner = function() end,
      SetText = function(_self, text)
        tooltipText = text
      end,
      Show = function() end,
      Hide = function() end,
    })

    local contact = { displayName = "Arthas", channel = "WOW", peerHasAddon = false }
    local view = HeaderView.Create(factory, pane, contact)
    HeaderView.Refresh(view, contact, nil, nil)
    local onEnter = view.headerAddonBadgeButton:GetScript("OnEnter")
    assert(type(onEnter) == "function", "addon badge button should have an OnEnter script")
    onEnter(view.headerAddonBadgeButton)
    assert(
      tooltipText == "Click to whisper this player an invite to WhisperMessenger.",
      "hovering the invite hint should explain the click, got: " .. tostring(tooltipText)
    )

    tooltipText = nil
    HeaderView.Refresh(view, contact, { inviteSent = true }, nil)
    onEnter(view.headerAddonBadgeButton)
    assert(tooltipText == nil, "a sent invite should not offer the click tooltip")

    rawset(_G, "GameTooltip", savedTooltip)
  end
end
