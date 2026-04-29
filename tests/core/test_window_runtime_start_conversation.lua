-- focused start-conversation flow regression
local StartConversation = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.StartConversation")

local function makeRuntime()
  return {
    localProfileId = "Player-1234",
    store = { conversations = {} },
    now = function()
      return 1000
    end,
  }
end

local function makeWindow(state)
  state = state or {}
  return {
    setTabMode = function(mode)
      state.tabMode = mode
    end,
    composer = {
      input = {
        SetFocus = function()
          state.focusCount = (state.focusCount or 0) + 1
        end,
      },
    },
  }
end

return function()
  -- Case 1: whitespace-only names return false and do not select
  do
    local runtime = makeRuntime()
    local selectedKey = nil
    local windowState = {}
    local startConversation = StartConversation.Create({
      runtime = runtime,
      getWindow = function()
        return makeWindow(windowState)
      end,
      selectConversation = function(key)
        selectedKey = key
      end,
    }).startConversation

    assert(startConversation(nil) == false, "expected nil to be rejected")
    assert(startConversation("") == false, "expected empty string to be rejected")
    assert(startConversation("   \t  ") == false, "expected whitespace to be rejected")
    assert(selectedKey == nil, "expected no selection on whitespace input")
    assert(windowState.tabMode == nil, "expected no tab change on whitespace input")
  end

  -- Case 2: existing conversation by display name is reused
  do
    local runtime = makeRuntime()
    runtime.store.conversations["Player-1234::JainaProudmoore"] = {
      displayName = "Jaina",
      channel = "WOW",
      conversationKey = "Player-1234::JainaProudmoore",
      messages = {},
    }

    local selectedKey = nil
    local windowState = {}
    local result = StartConversation.Create({
      runtime = runtime,
      getWindow = function()
        return makeWindow(windowState)
      end,
      selectConversation = function(key)
        selectedKey = key
      end,
    })

    assert(result.startConversation("Jaina") == true, "expected existing conversation to start")
    assert(selectedKey == "Player-1234::JainaProudmoore", "expected existing key reused")
    -- Existing entry should remain unchanged
    assert(runtime.store.conversations["Player-1234::JainaProudmoore"].displayName == "Jaina", "existing kept")
  end

  -- Case 3: new whisper conversation is created with stable shape
  do
    local runtime = makeRuntime()
    local windowState = {}
    local selectedKey = nil
    local result = StartConversation.Create({
      runtime = runtime,
      getWindow = function()
        return makeWindow(windowState)
      end,
      selectConversation = function(key)
        selectedKey = key
      end,
    })

    assert(result.startConversation("Thrall") == true, "expected new whisper to be created")
    assert(type(selectedKey) == "string" and selectedKey ~= "", "expected new conversation key to be selected")

    local newConversation = runtime.store.conversations[selectedKey]
    assert(newConversation ~= nil, "expected new conversation entry to exist")
    assert(newConversation.channel == "WOW", "expected channel WOW")
    assert(newConversation.conversationKey == selectedKey, "expected conversationKey set")
    assert(newConversation.displayName == "Thrall", "expected displayName preserved")
    assert(type(newConversation.messages) == "table", "expected messages table")
    assert(newConversation.unreadCount == 0, "expected unreadCount 0")
    assert(newConversation.lastActivityAt == 1000, "expected lastActivityAt from runtime.now")
  end

  -- Case 4: successful start forces whispers tab and focuses composer
  do
    local runtime = makeRuntime()
    local windowState = {}
    local result = StartConversation.Create({
      runtime = runtime,
      getWindow = function()
        return makeWindow(windowState)
      end,
      selectConversation = function() end,
    })

    assert(result.startConversation("Sylvanas") == true, "expected start to succeed")
    assert(windowState.tabMode == "whispers", "expected whispers tab to be forced")
    assert((windowState.focusCount or 0) >= 1, "expected composer input to be focused at least once")
  end

  -- Case 5: typed name colliding with a BN conversation creates a new WOW conversation.
  -- Lookup ignores BN entries so a typed "Uther" never re-uses "Uther#1234".
  do
    local runtime = makeRuntime()
    runtime.store.conversations["wow::BN::uther#1234"] = {
      conversationKey = "wow::BN::uther#1234",
      displayName = "Uther",
      channel = "BN",
      battleTag = "Uther#1234",
      messages = {},
    }
    local selectedKey = nil
    local result = StartConversation.Create({
      runtime = runtime,
      getWindow = function()
        return makeWindow({})
      end,
      selectConversation = function(key)
        selectedKey = key
      end,
    })

    assert(result.startConversation("Uther") == true, "expected typed name to create a new WOW conversation")
    assert(selectedKey ~= "wow::BN::uther#1234", "expected typed name to skip BN conversation")
    assert(runtime.store.conversations[selectedKey].channel == "WOW", "expected new conversation to be a WOW whisper")
    assert(runtime.store.conversations["wow::BN::uther#1234"] ~= nil, "BN conversation should remain intact")
  end

  -- Case 6: ambiguous base-name with multiple matches creates a new conversation rather than
  -- guessing which existing realm the user meant.
  do
    local runtime = makeRuntime()
    runtime.store.conversations["Player-1234::Arthas-Area52"] = {
      conversationKey = "Player-1234::Arthas-Area52",
      displayName = "Arthas-Area52",
      channel = "WOW",
      messages = {},
    }
    runtime.store.conversations["Player-1234::Arthas-Stormrage"] = {
      conversationKey = "Player-1234::Arthas-Stormrage",
      displayName = "Arthas-Stormrage",
      channel = "WOW",
      messages = {},
    }
    local selectedKey = nil
    local result = StartConversation.Create({
      runtime = runtime,
      getWindow = function()
        return makeWindow({})
      end,
      selectConversation = function(key)
        selectedKey = key
      end,
    })

    assert(result.startConversation("Arthas") == true, "ambiguous base-name should still succeed")
    assert(
      selectedKey ~= "Player-1234::Arthas-Area52" and selectedKey ~= "Player-1234::Arthas-Stormrage",
      "ambiguous base-name should not pick an existing conversation arbitrarily, got: " .. tostring(selectedKey)
    )
    assert(runtime.store.conversations["Player-1234::Arthas-Area52"] ~= nil, "existing Area52 conversation should remain")
    assert(runtime.store.conversations["Player-1234::Arthas-Stormrage"] ~= nil, "existing Stormrage conversation should remain")
  end

  -- Case 7: exact full-name match (case-insensitive, trimmed) reuses the existing conversation.
  do
    local runtime = makeRuntime()
    runtime.store.conversations["Player-1234::Arthas-Area52"] = {
      conversationKey = "Player-1234::Arthas-Area52",
      displayName = "Arthas-Area52",
      channel = "WOW",
      messages = {},
    }
    local selectedKey = nil
    local result = StartConversation.Create({
      runtime = runtime,
      getWindow = function()
        return makeWindow({})
      end,
      selectConversation = function(key)
        selectedKey = key
      end,
    })

    assert(result.startConversation("  arTHas-ARea52  ") == true, "case-insensitive full-name match should succeed")
    assert(selectedKey == "Player-1234::Arthas-Area52", "expected exact full-name match to reuse existing key")
  end
end
