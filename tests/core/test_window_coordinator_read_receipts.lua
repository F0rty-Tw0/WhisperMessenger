local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")

return function()
  local shown = true
  local window = {
    frame = {
      IsShown = function()
        return shown
      end,
      Show = function()
        shown = true
      end,
      Hide = function()
        shown = false
      end,
    },
    refreshSelection = function() end,
    refreshContacts = function() end,
  }
  local runtime = {
    availabilityByGUID = {},
    availabilityRequestedAt = {},
    sendStatusByConversation = {},
    now = function()
      return 1000
    end,
    chatApi = {},
    activeConversationKey = "k1",
    store = { conversations = { k1 = { messages = {} } } },
  }
  local synced = {}
  local coord = WindowCoordinator.Create({
    runtime = runtime,
    buildContacts = function()
      return { { channel = "WOW", conversationKey = "k1", displayName = "A" } }
    end,
    getWindow = function()
      return window
    end,
    isMythicRestricted = function()
      return false
    end,
    livePresenceSender = {
      SyncReadReceipts = function(_runtime, selectedContact)
        table.insert(synced, selectedContact and selectedContact.conversationKey or false)
        return true
      end,
    },
  })

  -- test_refresh_syncs_receipts_for_selected_conversation_when_visible
  coord.refreshWindow()
  assert(#synced == 1 and synced[1] == "k1", "receipts synced for the selected conversation")

  -- test_hidden_window_does_not_sync
  shown = false
  coord.refreshWindow()
  assert(#synced == 1, "hidden window sends no receipts")
end
