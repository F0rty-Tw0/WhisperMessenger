local FakeUI = require("tests.helpers.fake_ui")
local AutoOpenCoordinator = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator")
local Store = require("WhisperMessenger.Model.ConversationStore")
local ConversationOps = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.ConversationOps")
local EditBoxInterop = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.EditBoxInterop")

return function()
  local savedGlobals = {
    CreateFrame = _G.CreateFrame,
    C_Timer = _G.C_Timer,
    ChatEdit_DeactivateChat = _G.ChatEdit_DeactivateChat,
    InCombatLockdown = _G.InCombatLockdown,
    NUM_CHAT_WINDOWS = _G.NUM_CHAT_WINDOWS,
    ChatFrame1EditBox = _G.ChatFrame1EditBox,
    UIParent = _G.UIParent,
    C_BattleNet = _G.C_BattleNet,
    BNGetNumFriends = _G.BNGetNumFriends,
    _wmSuspended = _G._wmSuspended,
    hooksecurefunc = _G.hooksecurefunc,
    ChatFrameUtil = _G.ChatFrameUtil,
    ChatFrame_SendBNetTell = _G.ChatFrame_SendBNetTell,
    ChatFrame_SendTell = _G.ChatFrame_SendTell,
    ChatFrame_ReplyTell = _G.ChatFrame_ReplyTell,
    ChatFrame_ReplyTell2 = _G.ChatFrame_ReplyTell2,
  }
  local factory = FakeUI.NewFactory()
  local createdFrames = {}
  local timerCallbacks = {}
  local deactivated = {}
  local composerTexts = {}
  local sendTellCalls = {}
  local replyTellCalls = {}
  local outgoingCalls = {}
  local selectedConversationKeys = {}
  local autoOpenHookDeps = nil
  local inCombat = false
  local windowVisible = false

  local function findCreatedFrameWithScript(scriptName)
    for _, frame in ipairs(createdFrames) do
      if frame.scripts and frame.scripts[scriptName] then
        return frame
      end
    end

    return nil
  end

  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.NUM_CHAT_WINDOWS = 1
  _G._wmSuspended = false
  rawset(_G, "InCombatLockdown", function()
    return inCombat
  end)
  _G.C_Timer = {
    After = function(delaySeconds, callback)
      timerCallbacks[#timerCallbacks + 1] = {
        delaySeconds = delaySeconds,
        callback = callback,
      }
    end,
  }
  rawset(_G, "ChatEdit_DeactivateChat", function(editBox)
    deactivated[#deactivated + 1] = editBox
    if editBox.ClearFocus then
      editBox:ClearFocus()
    end
    if editBox.Hide then
      editBox:Hide()
    end
  end)
  rawset(_G, "CreateFrame", function(frameType, name, parent, template)
    local frame = factory.CreateFrame(frameType, name, parent, template)
    createdFrames[#createdFrames + 1] = frame
    return frame
  end)

  local runtime = {
    localProfileId = "me",
    accountState = {
      settings = {
        autoOpenIncoming = true,
        autoOpenOutgoing = true,
      },
    },
    store = {
      conversations = {
        ["wow::WOW::arthas-area52"] = {
          channel = "WOW",
          displayName = "Arthas-Area52",
        },
        ["wow::WOW::friend"] = {
          channel = "BN",
          displayName = "Friend#1234",
          battleTag = "Friend#1234",
          gameAccountName = "Thrall",
        },
      },
    },
    now = function()
      return 100
    end,
    setComposerText = function(text)
      composerTexts[#composerTexts + 1] = text
    end,
  }

  local sendTellResult = true
  local autoOpenHooks = {
    onIncomingWhisper = function() end,
    onOutgoingWhisper = function(conversationKey)
      outgoingCalls[#outgoingCalls + 1] = conversationKey
      return true
    end,
    onSendTell = function(target)
      sendTellCalls[#sendTellCalls + 1] = target
      return sendTellResult
    end,
    onReplyTell = function()
      replyTellCalls[#replyTellCalls + 1] = runtime.lastIncomingWhisperKey
      return runtime.lastIncomingWhisperKey ~= nil
    end,
  }

  local coordinator = AutoOpenCoordinator.Attach({
    runtime = runtime,
    accountState = runtime.accountState,
    windowRuntime = {
      selectConversation = function(conversationKey)
        selectedConversationKeys[#selectedConversationKeys + 1] = conversationKey
      end,
      isWindowVisible = function()
        return windowVisible
      end,
    },
    AutoOpenHooks = {
      Create = function(deps)
        autoOpenHookDeps = deps
        return autoOpenHooks
      end,
    },
    Identity = {
      FromWhisper = function(name)
        return {
          canonicalName = string.lower(name or ""),
          contactKey = "WOW::" .. tostring(name),
        }
      end,
      BuildConversationKey = function(profileId, contactKey)
        return profileId .. "::" .. contactKey
      end,
      FromBattleNet = function(bnetAccountID)
        return {
          canonicalName = tostring(bnetAccountID),
          contactKey = "BN::" .. tostring(bnetAccountID),
        }
      end,
    },
  })

  assert(runtime.onAutoOpen == autoOpenHooks.onIncomingWhisper, "expected incoming auto-open hook attachment")
  assert(runtime.onAutoOpenOutgoing == autoOpenHooks.onOutgoingWhisper, "expected outgoing auto-open hook attachment")
  assert(runtime.autoOpenHooks == autoOpenHooks, "expected runtime.autoOpenHooks to reference created hooks")
  assert(type(coordinator.installDeferredPoller) == "function", "expected deferred poller installer")

  assert(type(autoOpenHookDeps) == "table", "expected auto-open hook deps table")
  local findConversationKeyByName = rawget(autoOpenHookDeps, "findConversationKeyByName")
  assert(type(findConversationKeyByName) == "function", "expected findConversationKeyByName helper")
  assert(findConversationKeyByName("Arthas") == "wow::WOW::arthas-area52", "expected unique base-name WOW conversation lookup")
  assert(findConversationKeyByName("Friend#1234") == nil, "WOW lookup must not select a Battle.net conversation by battleTag")
  assert(findConversationKeyByName("Thrall") == nil, "WOW lookup must not select a Battle.net conversation by game account name")

  _G.C_BattleNet = {
    GetFriendAccountInfo = function(friendIndex)
      if friendIndex ~= 1 then
        return nil
      end

      return {
        bnetAccountID = 42,
        battleTag = "Friend#1234",
        accountName = "Friend",
        gameAccountInfo = {
          characterName = "Thrall",
        },
      }
    end,
  }
  _G.BNGetNumFriends = function()
    return 1
  end

  -- Set up globals for direct hook installation.
  local hookedFunctions = {}
  local bnetLauncherEditBox
  local bnetLauncherAttributes
  local characterLauncherEditBox = nil
  local characterLauncherAttributes
  local bnetHeaderUpdates = 0
  local textChangedHook
  rawset(_G, "hooksecurefunc", function(target, methodOrHandler, postHook)
    if type(target) == "table" then
      local methodName = methodOrHandler
      hookedFunctions["ChatFrameUtil." .. methodName] = hookedFunctions["ChatFrameUtil." .. methodName] or {}
      hookedFunctions["ChatFrameUtil." .. methodName][#hookedFunctions["ChatFrameUtil." .. methodName] + 1] = postHook
      local original = target[methodName]
      target[methodName] = function(...)
        original(...)
        postHook(...)
      end
      return
    end

    hookedFunctions[target] = hookedFunctions[target] or {}
    hookedFunctions[target][#hookedFunctions[target] + 1] = methodOrHandler
  end)
  _G.ChatFrameUtil = {
    SendBNetTell = function()
      bnetHeaderUpdates = bnetHeaderUpdates + 1
      bnetLauncherAttributes.chatType = "BN_WHISPER"
      bnetLauncherAttributes.tellTarget = "Friend#1234"
      bnetLauncherEditBox.chatType = "BN_WHISPER"
      bnetLauncherEditBox.tellTarget = "Friend#1234"
    end,
    SendTell = function(...)
      return _G.ChatFrameUtil.SendTellWithMessage(...)
    end,
    SendTellWithMessage = function()
      characterLauncherEditBox:SetFocus()
      characterLauncherAttributes.chatType = "WHISPER"
      characterLauncherAttributes.tellTarget = "Arthas"
      characterLauncherEditBox.chatType = "WHISPER"
      characterLauncherEditBox.tellTarget = "Arthas"
      characterLauncherEditBox._hookScripts.OnTextChanged[1](characterLauncherEditBox, false)
    end,
  }
  _G.ChatFrame_SendTell = function() end
  _G.ChatFrame_ReplyTell = function() end
  _G.ChatFrame_ReplyTell2 = function() end

  -- Given an existing Blizzard chat edit box before auto-open installs.
  local editBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
  local attributeState = {
    chatType = "WHISPER",
    stickyType = "PARTY",
    tellTarget = "Jaina",
  }

  function editBox:GetAttribute(key)
    return attributeState[key]
  end

  function editBox:SetAttribute(key, value)
    attributeState[key] = value
  end

  _G.ChatFrame1EditBox = editBox

  -- When deferred auto-open interception installs.
  coordinator.installDeferredPoller()
  assert(#timerCallbacks == 1 and timerCallbacks[1].delaySeconds == 0, "expected deferred poller timer callback")

  timerCallbacks[1].callback()

  -- Then interception is event-driven and does not install frame polling.
  local pollFrame = findCreatedFrameWithScript("OnUpdate")
  assert(pollFrame == nil, "expected auto-open interception not to install an OnUpdate frame")
  assert(editBox._hookScripts and editBox._hookScripts.OnEditFocusGained, "expected auto-open interception to hook edit-box focus")
  assert(editBox._hookScripts and editBox._hookScripts.OnTextChanged, "expected auto-open interception to hook edit-box text changes")

  local focusHook = editBox._hookScripts.OnEditFocusGained[1]
  textChangedHook = editBox._hookScripts.OnTextChanged[1]

  editBox.chatType = "WHISPER"
  editBox.stickyType = "PARTY"
  editBox.tellTarget = "Jaina"
  editBox:SetText("Need a summon")
  editBox:SetFocus()

  assert(#sendTellCalls == 1 and sendTellCalls[1] == "Jaina", "expected edit-box hook to route whisper target")
  assert(#composerTexts == 1 and composerTexts[1] == "Need a summon", "expected draft text moved into composer")
  assert(#deactivated == 1 and deactivated[1] == editBox, "expected edit box to close after interception")
  assert(editBox:GetAttribute("chatType") == "PARTY", "expected sticky chat type restored in secure state")
  assert(editBox:GetAttribute("tellTarget") == nil, "expected tell target cleared in secure state")
  assert(editBox:GetText() == "", "expected intercepted edit box text cleared")
  assert(editBox:HasFocus() == false, "expected intercepted edit box to lose focus")

  local bnEditBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
  local bnAttributeState = {
    chatType = "BN_WHISPER",
    stickyType = "SAY",
    tellTarget = "Friend#1234",
  }

  function bnEditBox:GetAttribute(key)
    return bnAttributeState[key]
  end

  function bnEditBox:SetAttribute(key, value)
    bnAttributeState[key] = value
  end

  bnEditBox.chatType = "BN_WHISPER"
  bnEditBox.stickyType = "SAY"
  bnEditBox.tellTarget = "Friend#1234"
  bnEditBox:SetText("BN draft")
  bnEditBox:SetFocus()
  _G.ChatFrame1EditBox = bnEditBox

  focusHook(bnEditBox)

  local expectedBnConversationKey = "me::BN::42"
  assert(
    #outgoingCalls == 1 and outgoingCalls[1] == expectedBnConversationKey,
    "expected BN interception to route through onOutgoingWhisper with created conversation key"
  )
  assert(
    runtime.store.conversations[expectedBnConversationKey] ~= nil,
    "expected BN interception to create a conversation when one does not already exist"
  )
  assert(
    runtime.store.conversations[expectedBnConversationKey].bnetAccountID == 42,
    "expected BN interception to preserve bnetAccountID on the created conversation"
  )
  assert(#composerTexts == 2 and composerTexts[2] == "BN draft", "expected BN draft text moved into composer")
  assert(#deactivated == 2 and deactivated[2] == bnEditBox, "expected BN edit box to close after interception")
  assert(bnEditBox:GetAttribute("chatType") == "SAY", "expected BN sticky chat type restored in secure state")
  assert(bnEditBox:GetAttribute("tellTarget") == nil, "expected BN tell target cleared in secure state")
  assert(bnEditBox:GetText() == "", "expected BN intercepted edit box text cleared")
  assert(bnEditBox:HasFocus() == false, "expected BN intercepted edit box to lose focus")

  -- test_stale_bn_state_does_not_hijack_explicit_character_whisper
  do
    local staleBnBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
    local staleBnAttrState = { chatType = "BN_WHISPER", stickyType = "SAY", tellTarget = "Friend#1234" }
    function staleBnBox:GetAttribute(key)
      return staleBnAttrState[key]
    end

    function staleBnBox:SetAttribute(key, value)
      staleBnAttrState[key] = value
    end

    staleBnBox.chatType = "BN_WHISPER"
    staleBnBox.tellTarget = "Friend#1234"
    staleBnBox.stickyType = "SAY"
    staleBnBox:SetText("/w Thrall hello")
    staleBnBox:SetFocus()
    _G.ChatFrame1EditBox = staleBnBox

    local prevSendTellCount = #sendTellCalls
    local prevOutgoingCount = #outgoingCalls
    local prevDeactivatedCount = #deactivated
    local prevComposerTextCount = #composerTexts
    textChangedHook(staleBnBox, true)

    assert(#sendTellCalls == prevSendTellCount + 1, "expected slash whisper draft to route through character whisper")
    assert(sendTellCalls[#sendTellCalls] == "Thrall", "expected slash whisper target parsed from /w command")
    assert(#outgoingCalls == prevOutgoingCount, "expected stale BN state not to open BNet conversation while typing /w")
    assert(#deactivated == prevDeactivatedCount + 1, "expected routed slash whisper draft to close Blizzard edit box")
    assert(composerTexts[#composerTexts] == "hello", "expected only slash whisper message body copied into composer")
    assert(#composerTexts == prevComposerTextCount + 1, "expected slash command prefix not to be copied into composer")
    assert(staleBnBox:GetText() == "", "expected routed slash whisper draft to clear default edit box")
    assert(staleBnBox:HasFocus() == false, "expected routed slash whisper draft to lose focus")

    local taintedTextBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
    local taintedTextAttrState = { chatType = "BN_WHISPER", stickyType = "SAY", tellTarget = "Friend#1234" }
    function taintedTextBox:GetAttribute(key)
      return taintedTextAttrState[key]
    end

    function taintedTextBox:SetAttribute(key, value)
      taintedTextAttrState[key] = value
    end

    taintedTextBox.chatType = "BN_WHISPER"
    taintedTextBox.tellTarget = "Friend#1234"
    taintedTextBox.stickyType = "SAY"
    taintedTextBox.GetText = function()
      error("attempt to read secret string value (tainted by 'WhisperMessenger')")
    end
    taintedTextBox:SetFocus()
    _G.ChatFrame1EditBox = taintedTextBox

    prevOutgoingCount = #outgoingCalls
    prevDeactivatedCount = #deactivated
    focusHook(taintedTextBox)

    assert(#outgoingCalls == prevOutgoingCount, "expected unreadable slash draft state not to route stale BNet conversation")
    assert(#deactivated == prevDeactivatedCount, "expected unreadable slash draft state to stay in Blizzard edit box")
    assert(taintedTextBox:HasFocus() == true, "expected unreadable slash draft state to keep focus")

    prevSendTellCount = #sendTellCalls
    prevOutgoingCount = #outgoingCalls
    local prevTimerCount = #timerCallbacks
    hookedFunctions["ChatFrame_SendTell"][1]("Thrall")

    assert(#sendTellCalls == prevSendTellCount + 1, "expected explicit SendTell target to route as character whisper")
    assert(sendTellCalls[#sendTellCalls] == "Thrall", "expected explicit SendTell target preserved")
    assert(#outgoingCalls == prevOutgoingCount, "expected explicit character whisper not to route through BNet conversation")
    assert(#timerCallbacks == prevTimerCount + 1, "expected explicit character whisper to schedule deferred close")
  end

  -- test_direct_hooks_installed_for_whisper_functions

  assert(hookedFunctions["ChatFrame_SendTell"] ~= nil, "expected ChatFrame_SendTell to be hooked")
  -- ChatFrame_ReplyTell / ChatFrame_ReplyTell2 are intentionally NOT hooked.
  -- When Blizzard's chatEditLastTell is tainted by a secret-string sender
  -- captured during Mythic+, Blizzard's ReplyTell body errors before our
  -- hook suffix fires and WoW's taint system attributes the crash to us for
  -- merely having the hook attached. /wr slash command is the taint-safe
  -- reply path.
  assert(
    hookedFunctions["ChatFrame_ReplyTell"] == nil,
    "ChatFrame_ReplyTell must NOT be hooked — causes false WhisperMessenger attribution on Blizzard taint"
  )
  assert(hookedFunctions["ChatFrame_ReplyTell2"] == nil, "ChatFrame_ReplyTell2 must NOT be hooked — same false-attribution issue")

  -- Reply-hook scenarios removed: ChatFrame_ReplyTell / ReplyTell2 are no
  -- longer hooked. The /wr slash command (covered by its own test file) is
  -- the taint-safe reply path via runtime.lastIncomingWhisperKey.

  -- test_active_retail_bnet_launcher_defers_edit_box_interception

  do
    local activeBNetBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
    local activeBNetAttributes = { chatType = "SAY", stickyType = "SAY" }
    function activeBNetBox:GetAttribute(key)
      return activeBNetAttributes[key]
    end

    function activeBNetBox:SetAttribute(key, value)
      activeBNetAttributes[key] = value
    end

    activeBNetBox.chatType = "SAY"
    activeBNetBox.stickyType = "SAY"
    activeBNetBox:SetText("Active BNet draft")
    activeBNetBox:SetFocus()
    _G.ChatFrame1EditBox = activeBNetBox
    bnetLauncherEditBox = activeBNetBox
    bnetLauncherAttributes = activeBNetAttributes

    local prevOutgoingCount = #outgoingCalls
    local prevDeactivatedCount = #deactivated
    local prevComposerTextCount = #composerTexts
    local prevTimerCount = #timerCallbacks
    _G.ChatFrameUtil.SendBNetTell()

    assert(bnetHeaderUpdates == 1, "expected active Battle.net launcher to update only its header")
    assert(#outgoingCalls == prevOutgoingCount, "expected secure launcher hook not to route synchronously")

    for index = prevTimerCount + 1, #timerCallbacks do
      timerCallbacks[index].callback()
    end

    assert(
      #outgoingCalls == prevOutgoingCount + 1 and outgoingCalls[#outgoingCalls] == "me::BN::42",
      "expected active Battle.net launcher to route exactly one Battle.net conversation"
    )
    assert(#timerCallbacks == prevTimerCount + 1, "expected secure launcher hook to defer interception")
    assert(#deactivated == prevDeactivatedCount + 1 and deactivated[#deactivated] == activeBNetBox, "expected active Battle.net edit box to close")
    assert(
      #composerTexts == prevComposerTextCount + 1 and composerTexts[#composerTexts] == "Active BNet draft",
      "expected active Battle.net draft transferred to composer"
    )
    assert(activeBNetBox:HasFocus() == false, "expected active Battle.net edit box to lose focus after deferred interception")
  end

  -- test_active_retail_character_launcher_defers_edit_box_interception

  do
    local activeCharacterBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
    local activeCharacterAttributes = { chatType = "SAY", stickyType = "SAY" }
    function activeCharacterBox:GetAttribute(key)
      return activeCharacterAttributes[key]
    end

    function activeCharacterBox:SetAttribute(key, value)
      activeCharacterAttributes[key] = value
    end

    activeCharacterBox.chatType = "SAY"
    activeCharacterBox.stickyType = "SAY"
    activeCharacterBox:SetText("Active character draft")
    activeCharacterBox:HookScript("OnEditFocusGained", focusHook)
    activeCharacterBox:HookScript("OnTextChanged", textChangedHook)
    _G.ChatFrame1EditBox = activeCharacterBox
    characterLauncherEditBox = activeCharacterBox
    characterLauncherAttributes = activeCharacterAttributes

    local prevSendTellCount = #sendTellCalls
    local prevDeactivatedCount = #deactivated
    local prevTimerCount = #timerCallbacks
    _G.ChatFrameUtil.SendTell()

    assert(#sendTellCalls == prevSendTellCount, "expected modern character launcher not to route synchronously")
    assert(#timerCallbacks == prevTimerCount + 1, "expected modern character launcher to schedule next-frame interception")

    timerCallbacks[#timerCallbacks].callback()

    assert(
      #sendTellCalls == prevSendTellCount + 1 and sendTellCalls[#sendTellCalls] == "Arthas",
      "expected deferred modern character launcher to route character target once"
    )
    assert(
      #deactivated == prevDeactivatedCount + 1 and deactivated[#deactivated] == activeCharacterBox,
      "expected deferred modern character launcher to close Blizzard edit box"
    )
  end

  -- test_direct_hook_intercepts_send_tell_with_deferred_close

  do
    local hookEditBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
    local hookAttrState = { chatType = "WHISPER", stickyType = "SAY", tellTarget = "Arthas" }
    function hookEditBox:GetAttribute(key)
      return hookAttrState[key]
    end

    function hookEditBox:SetAttribute(key, value)
      hookAttrState[key] = value
    end

    hookEditBox.chatType = "WHISPER"
    hookEditBox.tellTarget = "Arthas"
    hookEditBox.stickyType = "SAY"
    hookEditBox:SetText("")
    hookEditBox:SetFocus()
    _G.ChatFrame1EditBox = hookEditBox

    local prevSendTellCount = #sendTellCalls
    local prevDeactivatedCount = #deactivated
    local prevTimerCount = #timerCallbacks
    sendTellResult = true
    hookedFunctions["ChatFrame_SendTell"][1]("Arthas")

    assert(
      #sendTellCalls == prevSendTellCount + 1 and sendTellCalls[#sendTellCalls] == "Arthas",
      "expected direct hook to call onSendTell with target"
    )
    -- Edit box close is deferred to avoid taint
    assert(#deactivated == prevDeactivatedCount, "expected edit box NOT immediately closed (deferred)")
    assert(#timerCallbacks == prevTimerCount + 1, "expected C_Timer.After scheduled for deferred close")

    -- Fire the deferred timer to actually close the edit box
    timerCallbacks[#timerCallbacks].callback()
    assert(#deactivated == prevDeactivatedCount + 1, "expected edit box closed after deferred timer")
    assert(hookEditBox:HasFocus() == false, "expected edit box to lose focus after deferred close")
  end

  -- test_direct_hook_routes_to_visible_window_during_combat

  do
    local combatEditBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
    local combatAttrState = { chatType = "WHISPER", stickyType = "SAY", tellTarget = "Arthas" }
    function combatEditBox:GetAttribute(key)
      return combatAttrState[key]
    end

    function combatEditBox:SetAttribute(key, value)
      combatAttrState[key] = value
    end

    combatEditBox.chatType = "WHISPER"
    combatEditBox.tellTarget = "Arthas"
    combatEditBox.stickyType = "SAY"
    combatEditBox:SetText("")
    combatEditBox:SetFocus()
    _G.ChatFrame1EditBox = combatEditBox

    local prevSendTellCount = #sendTellCalls
    local prevDeactivatedCount = #deactivated
    local prevTimerCount = #timerCallbacks
    sendTellResult = true
    inCombat = true
    windowVisible = true
    hookedFunctions["ChatFrame_SendTell"][1]("Arthas")
    inCombat = false
    windowVisible = false

    assert(
      #sendTellCalls == prevSendTellCount + 1 and sendTellCalls[#sendTellCalls] == "Arthas",
      "expected direct hook to keep routing whisper in combat when messenger is visible"
    )
    assert(#deactivated == prevDeactivatedCount, "expected combat visible route to defer edit box close")
    assert(#timerCallbacks == prevTimerCount + 1, "expected deferred close timer when routing in combat")

    timerCallbacks[#timerCallbacks].callback()
    assert(#deactivated == prevDeactivatedCount + 1, "expected deferred close after combat visible route")
    assert(combatEditBox:HasFocus() == false, "expected focused default edit box to blur after combat route")
  end

  -- test_direct_hook_does_not_close_editbox_when_send_tell_fails

  do
    local failEditBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
    local failAttrState = { chatType = "WHISPER", stickyType = "SAY", tellTarget = "Nobody" }
    function failEditBox:GetAttribute(key)
      return failAttrState[key]
    end

    function failEditBox:SetAttribute(key, value)
      failAttrState[key] = value
    end

    failEditBox.chatType = "WHISPER"
    failEditBox.tellTarget = "Nobody"
    failEditBox.stickyType = "SAY"
    failEditBox:SetText("")
    failEditBox:SetFocus()
    _G.ChatFrame1EditBox = failEditBox

    local prevDeactivatedCount = #deactivated
    local prevTimerCount = #timerCallbacks
    sendTellResult = false
    hookedFunctions["ChatFrame_SendTell"][1]("Nobody")

    assert(#deactivated == prevDeactivatedCount, "expected edit box NOT closed when onSendTell returns false")
    assert(#timerCallbacks == prevTimerCount, "expected NO deferred timer when onSendTell fails")
    assert(failEditBox:HasFocus() == true, "expected edit box to keep focus when hook fails")
  end

  -- test_edit_box_hook_does_not_close_editbox_when_send_tell_fails

  do
    local pollerFailBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
    local pollerFailAttr = { chatType = "WHISPER", stickyType = "SAY", tellTarget = "Ghost" }
    function pollerFailBox:GetAttribute(key)
      return pollerFailAttr[key]
    end

    function pollerFailBox:SetAttribute(key, value)
      pollerFailAttr[key] = value
    end

    pollerFailBox.chatType = "WHISPER"
    pollerFailBox.tellTarget = "Ghost"
    pollerFailBox.stickyType = "SAY"
    pollerFailBox:SetText("")
    pollerFailBox:SetFocus()
    _G.ChatFrame1EditBox = pollerFailBox

    local prevDeactivatedCount = #deactivated
    sendTellResult = false
    focusHook(pollerFailBox)

    assert(#deactivated == prevDeactivatedCount, "expected edit-box hook NOT to close when onSendTell returns false")
    assert(pollerFailBox:HasFocus() == true, "expected edit box to keep focus when interception fails")
    sendTellResult = true
  end

  -- test_edit_box_hook_preserves_combat_typed_draft_after_combat_ends

  do
    local carriedDraftBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
    local carriedAttrState = { chatType = "WHISPER", stickyType = "SAY", tellTarget = "Arthas" }
    function carriedDraftBox:GetAttribute(key)
      return carriedAttrState[key]
    end

    function carriedDraftBox:SetAttribute(key, value)
      carriedAttrState[key] = value
    end

    carriedDraftBox.chatType = "WHISPER"
    carriedDraftBox.tellTarget = "Arthas"
    carriedDraftBox.stickyType = "SAY"
    carriedDraftBox:SetText("typed during combat")
    carriedDraftBox:SetFocus()
    _G.ChatFrame1EditBox = carriedDraftBox

    local prevSendTellCount = #sendTellCalls
    local prevDeactivatedCount = #deactivated
    inCombat = true
    windowVisible = false
    textChangedHook(carriedDraftBox, true)

    assert(#sendTellCalls == prevSendTellCount, "expected edit-box hook not to route a whisper draft in combat")
    assert(#deactivated == prevDeactivatedCount, "expected edit-box hook not to close Blizzard chat in combat")

    inCombat = false
    focusHook(carriedDraftBox)

    assert(#sendTellCalls == prevSendTellCount, "expected combat-carried draft to remain in Blizzard chat after combat ends")
    assert(#deactivated == prevDeactivatedCount, "expected combat-carried draft edit box to remain open after combat ends")
    assert(carriedDraftBox:GetText() == "typed during combat", "expected combat-carried draft text to remain unchanged after combat ends")
    assert(carriedDraftBox:HasFocus() == true, "expected combat-carried draft focus to remain in Blizzard chat after combat ends")
  end

  -- test_direct_hook_preserves_combat_typed_draft_after_combat_ends

  do
    local carriedDraftBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
    local carriedAttrState = { chatType = "WHISPER", stickyType = "SAY", tellTarget = "Arthas" }
    function carriedDraftBox:GetAttribute(key)
      return carriedAttrState[key]
    end

    function carriedDraftBox:SetAttribute(key, value)
      carriedAttrState[key] = value
    end

    carriedDraftBox.chatType = "WHISPER"
    carriedDraftBox.tellTarget = "Arthas"
    carriedDraftBox.stickyType = "SAY"
    carriedDraftBox:SetText("typed during combat")
    carriedDraftBox:SetFocus()
    _G.ChatFrame1EditBox = carriedDraftBox

    inCombat = true
    windowVisible = false
    textChangedHook(carriedDraftBox, true)
    inCombat = false

    local prevSendTellCount = #sendTellCalls
    local prevDeactivatedCount = #deactivated
    local prevTimerCount = #timerCallbacks
    hookedFunctions["ChatFrame_SendTell"][1]("Arthas")

    assert(#sendTellCalls == prevSendTellCount, "expected direct hook to keep combat-carried draft in Blizzard chat after combat ends")
    assert(#deactivated == prevDeactivatedCount, "expected direct hook not to close combat-carried draft edit box")
    assert(#timerCallbacks == prevTimerCount, "expected direct hook not to schedule deferred close for combat-carried draft")
    assert(carriedDraftBox:GetText() == "typed during combat", "expected direct hook to preserve combat-carried draft text")
    assert(carriedDraftBox:HasFocus() == true, "expected direct hook to preserve focus for combat-carried draft")
  end

  -- test_edit_box_hook_routes_again_after_preserved_draft_cleared

  do
    local resumedBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
    local resumedAttrState = { chatType = "WHISPER", stickyType = "SAY", tellTarget = "Arthas" }
    function resumedBox:GetAttribute(key)
      return resumedAttrState[key]
    end

    function resumedBox:SetAttribute(key, value)
      resumedAttrState[key] = value
    end

    resumedBox.chatType = "WHISPER"
    resumedBox.tellTarget = "Arthas"
    resumedBox.stickyType = "SAY"
    resumedBox:SetText("typed during combat")
    resumedBox:SetFocus()
    _G.ChatFrame1EditBox = resumedBox

    inCombat = true
    windowVisible = false
    textChangedHook(resumedBox, true)
    inCombat = false

    resumedBox:SetText("")
    sendTellResult = true
    local prevSendTellCount = #sendTellCalls
    local prevDeactivatedCount = #deactivated
    textChangedHook(resumedBox, true)

    assert(
      #sendTellCalls == prevSendTellCount + 1 and sendTellCalls[#sendTellCalls] == "Arthas",
      "expected routing to resume once preserved combat draft is cleared"
    )
    assert(
      #deactivated == prevDeactivatedCount + 1 and deactivated[#deactivated] == resumedBox,
      "expected edit-box hook to close Blizzard chat once the preserved draft is cleared"
    )
    assert(resumedBox:HasFocus() == false, "expected cleared draft edit box to lose focus once normal routing resumes")
  end

  -- test_text_changed_hook_tolerates_tainted_has_focus_during_lockdown

  do
    local taintedBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
    local taintedAttrState = { chatType = "WHISPER", stickyType = "SAY", tellTarget = "Arthas" }
    function taintedBox:GetAttribute(key)
      return taintedAttrState[key]
    end
    function taintedBox:SetAttribute(key, value)
      taintedAttrState[key] = value
    end
    taintedBox.chatType = "WHISPER"
    taintedBox.tellTarget = "Arthas"
    taintedBox.stickyType = "SAY"
    taintedBox:SetText("draft")
    -- Simulate WoW secret-boolean taint: HasFocus() throws when its return
    -- value is tested in a boolean context. In our test env we approximate
    -- this by making the call itself throw, which pcall catches identically.
    local hasFocusCallCount = 0
    taintedBox.HasFocus = function()
      hasFocusCallCount = hasFocusCallCount + 1
      error("attempt to perform boolean test on a secret boolean value (tainted by 'WhisperMessenger')")
    end
    _G.ChatFrame1EditBox = taintedBox

    local prevSendTellCount = #sendTellCalls
    local prevDeactivatedCount = #deactivated

    -- Given auto-open interception is suspended in restricted content.
    _G._wmSuspended = true

    -- When Blizzard reports a user text change.
    local suspendedOk, suspendedError = pcall(textChangedHook, taintedBox, true)

    -- Then the hard bail happens before reading focus state.
    assert(suspendedOk, "expected suspended text hook to return safely, got: " .. tostring(suspendedError))
    assert(hasFocusCallCount == 0, "expected suspended text hook not to read HasFocus")
    _G._wmSuspended = false

    -- Combat path: the text-change hook should gracefully ignore tainted focus.
    inCombat = true
    windowVisible = false
    local ok1, err1 = pcall(textChangedHook, taintedBox, true)
    assert(ok1, "expected combat text hook to survive tainted HasFocus, got: " .. tostring(err1))

    -- Interception path: visible window during combat.
    windowVisible = true
    local ok2, err2 = pcall(textChangedHook, taintedBox, true)
    assert(ok2, "expected interception text hook to survive tainted HasFocus, got: " .. tostring(err2))

    assert(#sendTellCalls == prevSendTellCount, "expected no whisper routing when HasFocus is tainted")
    assert(#deactivated == prevDeactivatedCount, "expected no edit box close when HasFocus is tainted")

    inCombat = false
    windowVisible = false
  end

  -- test_edit_box_hooks_reuse_interception_dependencies

  do
    local observedDependencies = {}
    local originalInterceptEditBox = EditBoxInterop.interceptEditBox
    EditBoxInterop.interceptEditBox = function(_, _, dependencies)
      observedDependencies[#observedDependencies + 1] = dependencies
      return false
    end

    local ordinaryChatBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
    local ordinaryChatState = { chatType = "SAY", stickyType = "SAY" }
    function ordinaryChatBox:GetAttribute(key)
      return ordinaryChatState[key]
    end
    function ordinaryChatBox:SetAttribute(key, value)
      ordinaryChatState[key] = value
    end
    ordinaryChatBox.chatType = "SAY"
    ordinaryChatBox.stickyType = "SAY"
    ordinaryChatBox:SetText("hello")
    ordinaryChatBox:SetFocus()

    -- Given two edit-box events need the same interception services.
    -- When focus and user text callbacks are processed.
    focusHook(ordinaryChatBox)
    textChangedHook(ordinaryChatBox, true)

    EditBoxInterop.interceptEditBox = originalInterceptEditBox

    -- Then the immutable dependency table is reused between callbacks.
    assert(#observedDependencies == 2, "expected both edit-box callbacks to reach interception")
    assert(observedDependencies[1] == observedDependencies[2], "expected edit-box callbacks to reuse dependencies")
  end

  -- test_text_changed_hook_does_not_route_partial_slash_whisper_target
  -- Regression: typing `/w` followed by a name in default chat must not auto-open
  -- the messenger on every keystroke. The auto-open should only fire after the
  -- user finishes typing the target name (signalled by trailing whitespace before
  -- the body), so `/w S`, `/w Sh`, `/w Shalomonk` all stay in the default chat box.

  do
    local partialBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
    local partialAttrState = { chatType = "OPENCHAT", stickyType = "SAY" }
    function partialBox:GetAttribute(key)
      return partialAttrState[key]
    end
    function partialBox:SetAttribute(key, value)
      partialAttrState[key] = value
    end
    partialBox.chatType = "OPENCHAT"
    partialBox.stickyType = "SAY"
    partialBox:SetFocus()
    _G.ChatFrame1EditBox = partialBox

    sendTellResult = true
    local prevSendTellCount = #sendTellCalls
    local prevDeactivatedCount = #deactivated

    local partialDrafts = { "/w S", "/w Sh", "/w Shalomonk" }
    for index = 1, #partialDrafts do
      local draft = partialDrafts[index]
      partialBox:SetText(draft)
      partialBox:SetFocus()
      textChangedHook(partialBox, true)
      assert(#sendTellCalls == prevSendTellCount, "expected partial '/w' draft '" .. draft .. "' not to route through onSendTell")
      assert(#deactivated == prevDeactivatedCount, "expected partial '/w' draft '" .. draft .. "' to remain in Blizzard chat edit box")
      assert(partialBox:GetText() == draft, "expected partial '/w' draft text preserved while typing")
      assert(partialBox:HasFocus() == true, "expected partial '/w' draft to keep focus while typing")
    end

    -- Once the user types a space after the name, the text hook routes.
    partialBox:SetText("/w Shalomonk ")
    partialBox:SetFocus()
    textChangedHook(partialBox, true)
    assert(#sendTellCalls == prevSendTellCount + 1, "expected committed '/w name ' draft to route through onSendTell")
    assert(sendTellCalls[#sendTellCalls] == "Shalomonk", "expected committed slash whisper target preserved")
    assert(#deactivated == prevDeactivatedCount + 1, "expected committed slash whisper draft to close Blizzard edit box")
  end

  -- Direct auto-open operations use store retention instead of bypassing the cap.
  do
    local whisperStore = Store.New({ maxConversations = 1 })
    whisperStore.conversations.existing = {
      displayName = "Existing-Realm",
      channel = "WOW",
      messages = {},
      unreadCount = 0,
      lastActivityAt = 1,
    }
    local whisperRuntime = {
      localProfileId = "me",
      store = whisperStore,
      now = function()
        return 100
      end,
    }
    ConversationOps.ensureConversation(whisperRuntime, "me::WOW::new", "New-Realm")
    assert(whisperStore.conversations.existing == nil, "auto-open WOW creation must evict the eligible oldest conversation")
    assert(whisperStore.conversations["me::WOW::new"] ~= nil, "auto-open WOW creation must retain its requested key")

    local bnetStore = Store.New({ maxConversations = 1 })
    bnetStore.conversations.existing = {
      displayName = "Existing-Realm",
      channel = "WOW",
      messages = {},
      unreadCount = 0,
      lastActivityAt = 1,
    }
    local bnetRuntime = {
      localProfileId = "me",
      store = bnetStore,
      now = function()
        return 100
      end,
    }
    local bnetKey = ConversationOps.ensureBattleNetConversation(bnetRuntime, {
      FromBattleNet = function(bnetAccountID)
        return {
          canonicalName = tostring(bnetAccountID),
          contactKey = "BN::" .. tostring(bnetAccountID),
        }
      end,
      BuildConversationKey = function(profileId, contactKey)
        return profileId .. "::" .. contactKey
      end,
    }, {
      bnetAccountID = 42,
      battleTag = "Friend#1234",
    })
    assert(bnetStore.conversations.existing == nil, "auto-open BNet creation must evict the eligible oldest conversation")
    assert(bnetStore.conversations[bnetKey] ~= nil, "auto-open BNet creation must retain its requested key")
  end
  rawset(_G, "CreateFrame", savedGlobals.CreateFrame)
  _G.C_Timer = savedGlobals.C_Timer
  rawset(_G, "ChatEdit_DeactivateChat", savedGlobals.ChatEdit_DeactivateChat)
  rawset(_G, "InCombatLockdown", savedGlobals.InCombatLockdown)
  _G.NUM_CHAT_WINDOWS = savedGlobals.NUM_CHAT_WINDOWS
  _G.ChatFrame1EditBox = savedGlobals.ChatFrame1EditBox
  _G.UIParent = savedGlobals.UIParent
  _G.C_BattleNet = savedGlobals.C_BattleNet
  _G.BNGetNumFriends = savedGlobals.BNGetNumFriends
  _G._wmSuspended = savedGlobals._wmSuspended
  rawset(_G, "hooksecurefunc", savedGlobals.hooksecurefunc)
  _G.ChatFrameUtil = savedGlobals.ChatFrameUtil
  _G.ChatFrame_SendBNetTell = savedGlobals.ChatFrame_SendBNetTell
  _G.ChatFrame_SendTell = savedGlobals.ChatFrame_SendTell
  _G.ChatFrame_ReplyTell = savedGlobals.ChatFrame_ReplyTell
  _G.ChatFrame_ReplyTell2 = savedGlobals.ChatFrame_ReplyTell2
end
