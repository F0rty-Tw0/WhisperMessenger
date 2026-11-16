-- The conversation pane takes the window's row actions as one table
-- (options.rowActions) and hands it to the transcript's player menu, the
-- header menu and the header's invite badge.
local FakeUI = require("tests.helpers.fake_ui")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")
local HeaderMenu = require("WhisperMessenger.UI.ConversationPane.HeaderMenu")

local CONTACT = { displayName = "Arthas", conversationKey = "me::WOW::arthas", channel = "WOW", peerHasAddon = false }

-- Builds the pane; returns it with what the player menu and the header menu were bound with.
local function createPane(options)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(600, 420)
  local bound = {}
  local bindPlayerMenu, bindHeaderMenu = TranscriptSetup.BindPlayerMenu, HeaderMenu.Bind
  rawset(TranscriptSetup, "BindPlayerMenu", function(transcript, view, rowActions)
    bound.playerMenuActions = rowActions
    return bindPlayerMenu(transcript, view, rowActions)
  end)
  rawset(HeaderMenu, "Bind", function(headerFrame, view, headerOptions, contextMenu)
    bound.headerOptions = headerOptions
    return bindHeaderMenu(headerFrame, view, headerOptions, contextMenu)
  end)
  local view = ConversationPane.Create(factory, parent, CONTACT, { messages = {} }, options)
  rawset(TranscriptSetup, "BindPlayerMenu", bindPlayerMenu)
  rawset(HeaderMenu, "Bind", bindHeaderMenu)
  return view, bound
end

return function()
  -- test_player_menu_and_header_menu_get_the_row_actions_table_itself
  do
    local rowActions = { onMarkUnread = function() end, whoPlayer = function() end }
    local _, bound = createPane({ rowActions = rowActions })
    assert(bound.playerMenuActions == rowActions, "the transcript's player menu gets the table")
    assert(bound.headerOptions.rowActions == rowActions, "the header menu gets the same table")
  end

  -- test_invite_badge_reads_its_callbacks_from_the_row_actions
  do
    local rowActions = {
      onInviteContact = function() end,
      canInviteContact = function()
        return true
      end,
    }
    local view = createPane({ rowActions = rowActions })
    assert(view.onInviteContact == rowActions.onInviteContact, "invite click reaches the window callback")
    assert(view.canInviteContact == rowActions.canInviteContact, "the invite-link setting is read through the table")
  end

  -- test_actions_outside_the_row_actions_table_are_not_read
  do
    local view, bound = createPane({ onInviteContact = function() end, whoPlayer = function() end })
    assert(view.onInviteContact == nil, "only options.rowActions feeds the invite badge")
    assert(bound.playerMenuActions.whoPlayer == nil, "and the transcript's player menu")
  end

  -- test_pane_without_row_actions_has_no_invite_callbacks
  do
    local view = createPane({ rowActions = {} })
    assert(view.onInviteContact == nil and view.canInviteContact == nil, "absent actions stay absent")
  end
end
