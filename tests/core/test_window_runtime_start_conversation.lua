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
end
