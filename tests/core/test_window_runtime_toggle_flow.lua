local ToggleFlow = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ToggleFlow")

return function()
  local ensureCalls = 0
  local visible = false
  local setVisibleCalls = {}
  local selected = {}
  local refreshes = 0
  local tabMode = "whispers"
  local unreadKey = nil

  local runtime = {
    activeConversationKey = "party::me",
    store = {
      conversations = {
        ["wow::jaina"] = { channel = "WOW" },
        ["party::me"] = { channel = "PARTY" },
      },
    },
  }

  local flow = ToggleFlow.Create({
    runtime = runtime,
    badgeFilter = {
      IsGroupChannel = function(channel)
        return channel == "PARTY"
      end,
    },
    ensureWindow = function()
      ensureCalls = ensureCalls + 1
    end,
    isWindowVisible = function()
      return visible
    end,
    setWindowVisible = function(nextVisible)
      visible = nextVisible
      setVisibleCalls[#setVisibleCalls + 1] = nextVisible
    end,
    getWindow = function()
      return {
        getTabMode = function()
          return tabMode
        end,
      }
    end,
    findLatestUnreadKey = function()
      return unreadKey
    end,
    selectConversation = function(conversationKey)
      selected[#selected + 1] = conversationKey
    end,
    refreshWindow = function()
      refreshes = refreshes + 1
    end,
  })

  unreadKey = "wow::jaina"
  flow.toggle()
  assert(ensureCalls == 1, "open should ensure window")
  assert(setVisibleCalls[1] == true, "open should show window")
  assert(selected[1] == "wow::jaina", "matching unread whisper should be selected on Whispers tab")
  assert(refreshes == 0, "selecting target should skip fallback refresh")

  visible = false
  unreadKey = "party::me"
  runtime.activeConversationKey = "wow::jaina"
  tabMode = "whispers"
  flow.toggle()
  assert(#selected == 2 and selected[2] == "wow::jaina", "mismatched unread group should fall back to active whisper")

  visible = false
  unreadKey = "wow::jaina"
  runtime.activeConversationKey = "party::me"
  tabMode = "groups"
  flow.toggle()
  assert(#selected == 3 and selected[3] == "party::me", "mismatched unread whisper should not steal Groups tab")

  visible = false
  unreadKey = nil
  runtime.activeConversationKey = "missing-key"
  tabMode = "groups"
  flow.toggle()
  assert(#selected == 4 and selected[4] == "missing-key", "missing active conversation preserves legacy select behavior")

  visible = true
  unreadKey = "wow::jaina"
  tabMode = "whispers"
  flow.toggle()
  assert(setVisibleCalls[#setVisibleCalls] == false, "closing should hide window")
  assert(refreshes == 1, "closing should refresh once")
end
