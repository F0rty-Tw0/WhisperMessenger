local EditBoxInterop = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.EditBoxInterop")
local ConversationOps = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.ConversationOps")
local AutoOpenHooks = require("WhisperMessenger.Core.Bootstrap.AutoOpenHooks")
local GameChatRead = require("WhisperMessenger.Core.Bootstrap.GameChatRead")
local Identity = require("WhisperMessenger.Model.Identity")
local Store = require("WhisperMessenger.Model.ConversationStore")

local OLD_KEY = "me::WOW::old-realm"

-- A store at its one-conversation cap, holding one old character chat.
local function makeRuntime()
  local runtime = { localProfileId = "me", store = Store.New({ maxConversations = 1 }) }
  Store.EnsureConversation(runtime.store, OLD_KEY, { channel = "WOW", displayName = "Old-Realm", lastActivityAt = 1 })
  return runtime
end

local function makeHooks(runtime, autoOpenOutgoing)
  return AutoOpenHooks.Create({
    getSettings = function()
      return { autoOpenOutgoing = autoOpenOutgoing }
    end,
    isWindowVisible = function()
      return false
    end,
    isInCombat = function()
      return false
    end,
    ensureWindow = function() end,
    setWindowVisible = function() end,
    selectConversation = function() end,
    focusComposer = function() end,
    markRead = function(conversationKey)
      return GameChatRead.Mark(runtime, conversationKey)
    end,
  })
end

local function makeInterceptDeps()
  return {
    identity = Identity,
    bnetApi = {
      GetFriendAccountInfo = function(_index)
        return { bnetAccountID = 99, battleTag = "New#1" }
      end,
    },
    getNumFriends = function()
      return 1
    end,
    deactivateChat = function() end,
    ensureBattleNetConversation = ConversationOps.ensureBattleNetConversation,
    battleNetConversationKey = ConversationOps.battleNetConversationKey,
  }
end

local function countBattleNetConversations(runtime)
  local count = 0
  for _, conversation in pairs(runtime.store.conversations) do
    if conversation.channel == "BN" then
      count = count + 1
    end
  end
  return count
end

local function makeEditBox(attributes)
  return {
    GetAttribute = function(_self, key)
      return attributes[key]
    end,
    SetAttribute = function(_self, key, value)
      attributes[key] = value
    end,
    GetText = function()
      return ""
    end,
    SetText = function() end,
    Hide = function() end,
  }
end

return function()
  -- test_close_edit_box_resets_whisper_sticky_after_messenger_takes_over
  --
  -- A whisper actually sent through Blizzard chat (e.g. /r while the addon
  -- was suspended in M+) leaves stickyType=WHISPER. Once the messenger has
  -- taken the whisper over, keeping that sticky means every later Enter
  -- re-opens the messenger and the user can never reach Say/General.
  do
    local attributes = { chatType = "WHISPER", stickyType = "WHISPER", tellTarget = "Jaina" }
    EditBoxInterop.closeEditBox({}, makeEditBox(attributes), nil)
    assert(attributes.chatType == "SAY", "whisper sticky must reset chatType to SAY, got " .. tostring(attributes.chatType))
    assert(attributes.stickyType == "SAY", "whisper sticky must reset stickyType to SAY, got " .. tostring(attributes.stickyType))
    assert(attributes.tellTarget == nil, "whisper sticky must clear tellTarget")
  end

  -- test_close_edit_box_resets_bnet_whisper_sticky_after_messenger_takes_over
  do
    local attributes = { chatType = "BN_WHISPER", stickyType = "BN_WHISPER", tellTarget = "Friend#1234" }
    EditBoxInterop.closeEditBox({}, makeEditBox(attributes), nil)
    assert(attributes.chatType == "SAY", "BN whisper sticky must reset chatType to SAY, got " .. tostring(attributes.chatType))
    assert(attributes.stickyType == "SAY", "BN whisper sticky must reset stickyType to SAY, got " .. tostring(attributes.stickyType))
    assert(attributes.tellTarget == nil, "BN whisper sticky must clear tellTarget")
  end

  -- test_close_edit_box_keeps_non_whisper_sticky_untouched
  do
    local attributes = { chatType = "WHISPER", stickyType = "PARTY", tellTarget = "Jaina" }
    EditBoxInterop.closeEditBox({}, makeEditBox(attributes), nil)
    assert(attributes.chatType == "PARTY", "non-whisper sticky must restore chatType to sticky")
    assert(attributes.stickyType == "PARTY", "non-whisper sticky must stay as-is")
    assert(attributes.tellTarget == nil, "non-whisper sticky must clear tellTarget")
  end

  -- test_unrouted_bnet_draft_creates_no_conversation
  --
  -- A Battle.net whisper typed in the game's chat that WM does not take over
  -- must not add a conversation, nor evict an older one at the store cap.
  do
    local runtime = makeRuntime()
    local editBox = makeEditBox({ chatType = "BN_WHISPER", tellTarget = "New#1" })
    EditBoxInterop.interceptEditBox(runtime, makeHooks(runtime, false), makeInterceptDeps(), editBox)
    assert(runtime.store.conversations[OLD_KEY] ~= nil, "the old chat must not be evicted")
    assert(countBattleNetConversations(runtime) == 0, "no Battle.net conversation may be created")
  end

  -- test_unrouted_bnet_draft_marks_existing_conversation_read
  do
    local runtime = makeRuntime()
    runtime.store.config.maxConversations = nil
    local accountInfo = { bnetAccountID = 99, battleTag = "New#1" }
    local key = ConversationOps.ensureBattleNetConversation(runtime, Identity, accountInfo)
    runtime.store.conversations[key].unreadCount = 2
    local editBox = makeEditBox({ chatType = "BN_WHISPER", tellTarget = "New#1" })
    EditBoxInterop.interceptEditBox(runtime, makeHooks(runtime, false), makeInterceptDeps(), editBox)
    assert(runtime.store.conversations[key].unreadCount == 0, "the existing Battle.net chat is marked read")
  end

  -- test_routed_bnet_draft_creates_conversation_and_opens
  do
    local runtime = makeRuntime()
    runtime.store.config.maxConversations = nil
    local closed = false
    local deps = makeInterceptDeps()
    deps.deactivateChat = function()
      closed = true
    end
    local editBox = makeEditBox({ chatType = "BN_WHISPER", tellTarget = "New#1" })
    local handled = EditBoxInterop.interceptEditBox(runtime, makeHooks(runtime, true), deps, editBox)
    assert(handled == true, "the BN draft is handled")
    assert(countBattleNetConversations(runtime) == 1, "a routed BN whisper still creates its conversation")
    assert(closed == true, "the game's edit box closes once WM takes over")
  end
end
