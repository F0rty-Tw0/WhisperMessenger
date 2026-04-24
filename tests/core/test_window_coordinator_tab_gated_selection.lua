-- When the user is on the Groups tab but `runtime.activeConversationKey`
-- still points at a whisper (because the per-tab-memory swap cleared the
-- pane but didn't reset the persistent key), subsequent refreshes must not
-- pull the whisper back into the conversation pane. The selection state
-- returned from refreshContacts must match the active tab.

local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")

local function makeWindow(tabMode)
  return {
    frame = {
      shown = true,
      IsShown = function()
        return true
      end,
    },
    refreshSelection = function() end,
    getTabMode = function()
      return tabMode
    end,
  }
end

local function makeRuntime(activeKey)
  return {
    availabilityByGUID = {},
    availabilityRequestedAt = {},
    now = function()
      return 1000
    end,
    chatApi = {},
    activeConversationKey = activeKey,
    store = {
      conversations = {
        ["me::WOW::jaina"] = { lastMessage = { text = "hi", sentAt = 100 } },
        ["PARTY::1"] = { lastMessage = { text = "ready", sentAt = 100 } },
      },
    },
  }
end

return function()
  -- test_groups_tab_suppresses_whisper_selection_when_active_key_is_stale
  do
    local runtime = makeRuntime("me::WOW::jaina")
    local contacts = {
      { conversationKey = "me::WOW::jaina", channel = "WOW" },
      { conversationKey = "PARTY::1", channel = "PARTY" },
    }
    local coord = WindowCoordinator.Create({
      runtime = runtime,
      buildContacts = function()
        return contacts
      end,
      getWindow = function()
        return makeWindow("groups")
      end,
      getIcon = function()
        return {}
      end,
      buildMessagePreview = function()
        return nil
      end,
      isMythicRestricted = function()
        return false
      end,
      requestAvailability = function() end,
    })

    local nextState = coord.refreshContacts()
    local key = nextState.selectedContact and nextState.selectedContact.conversationKey
    assert(
      key ~= "me::WOW::jaina",
      "pane must not surface a whisper selection while the Groups tab is active; got " .. tostring(key)
    )
  end

  -- test_whispers_tab_still_selects_whisper_when_active_key_is_whisper
  do
    local runtime = makeRuntime("me::WOW::jaina")
    local contacts = {
      { conversationKey = "me::WOW::jaina", channel = "WOW" },
    }
    local coord = WindowCoordinator.Create({
      runtime = runtime,
      buildContacts = function()
        return contacts
      end,
      getWindow = function()
        return makeWindow("whispers")
      end,
      getIcon = function()
        return {}
      end,
      buildMessagePreview = function()
        return nil
      end,
      isMythicRestricted = function()
        return false
      end,
      requestAvailability = function() end,
    })

    local nextState = coord.refreshContacts()
    local key = nextState.selectedContact and nextState.selectedContact.conversationKey
    assert(key == "me::WOW::jaina", "regression: whispers tab must still select whisper; got " .. tostring(key))
  end

  -- test_groups_tab_keeps_group_selection_when_key_matches_tab
  do
    local runtime = makeRuntime("PARTY::1")
    local contacts = {
      { conversationKey = "PARTY::1", channel = "PARTY" },
    }
    local coord = WindowCoordinator.Create({
      runtime = runtime,
      buildContacts = function()
        return contacts
      end,
      getWindow = function()
        return makeWindow("groups")
      end,
      getIcon = function()
        return {}
      end,
      buildMessagePreview = function()
        return nil
      end,
      isMythicRestricted = function()
        return false
      end,
      requestAvailability = function() end,
    })

    local nextState = coord.refreshContacts()
    local key = nextState.selectedContact and nextState.selectedContact.conversationKey
    assert(key == "PARTY::1", "regression: groups tab must still select group; got " .. tostring(key))
  end
end
