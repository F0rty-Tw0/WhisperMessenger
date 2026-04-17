local FakeUI = require("tests.helpers.fake_ui")
local AutoOpenCoordinator = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator")

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
          displayName = "Arthas-Area52",
        },
        ["wow::WOW::friend"] = {
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
  assert(findConversationKeyByName("Arthas") == "wow::WOW::arthas-area52", "expected base-name conversation lookup")
  assert(findConversationKeyByName("Friend#1234") == "wow::WOW::friend", "expected battleTag conversation lookup")
  assert(findConversationKeyByName("Thrall") == "wow::WOW::friend", "expected gameAccountName conversation lookup")

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

  -- Set up globals for direct hook installation
  local hookedFunctions = {}
  rawset(_G, "hooksecurefunc", function(name, handler)
    hookedFunctions[name] = hookedFunctions[name] or {}
    hookedFunctions[name][#hookedFunctions[name] + 1] = handler
  end)
  _G.ChatFrame_SendTell = function() end
  _G.ChatFrame_ReplyTell = function() end
  _G.ChatFrame_ReplyTell2 = function() end
  coordinator.installDeferredPoller()
  assert(#timerCallbacks == 1 and timerCallbacks[1].delaySeconds == 0, "expected deferred poller timer callback")

  timerCallbacks[1].callback()

  local pollFrame = findCreatedFrameWithScript("OnUpdate")
  assert(pollFrame ~= nil, "expected edit-box poll frame installation")

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

  editBox.chatType = "WHISPER"
  editBox.stickyType = "PARTY"
  editBox.tellTarget = "Jaina"
  editBox:SetText("Need a summon")
  editBox:SetFocus()
  _G.ChatFrame1EditBox = editBox

  pollFrame.scripts.OnUpdate(pollFrame)

  assert(#sendTellCalls == 1 and sendTellCalls[1] == "Jaina", "expected poller to route whisper target through hooks")
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

  pollFrame.scripts.OnUpdate(pollFrame)

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
  assert(
    hookedFunctions["ChatFrame_ReplyTell2"] == nil,
    "ChatFrame_ReplyTell2 must NOT be hooked — same false-attribution issue"
  )

  -- Reply-hook scenarios removed: ChatFrame_ReplyTell / ReplyTell2 are no
  -- longer hooked. The /wr slash command (covered by its own test file) is
  -- the taint-safe reply path via runtime.lastIncomingWhisperKey.

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

  -- test_poller_does_not_close_editbox_when_send_tell_fails

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
    pollFrame.scripts.OnUpdate(pollFrame)

    assert(#deactivated == prevDeactivatedCount, "expected poller NOT to close edit box when onSendTell returns false")
    assert(pollerFailBox:HasFocus() == true, "expected edit box to keep focus when poller hook fails")
    sendTellResult = true
  end

  -- test_poller_preserves_combat_typed_draft_after_combat_ends

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
    pollFrame.scripts.OnUpdate(pollFrame)

    assert(#sendTellCalls == prevSendTellCount, "expected poller not to route whisper draft while still in combat")
    assert(#deactivated == prevDeactivatedCount, "expected poller not to close Blizzard chat edit box while in combat")

    inCombat = false
    pollFrame.scripts.OnUpdate(pollFrame)

    assert(
      #sendTellCalls == prevSendTellCount,
      "expected combat-carried draft to remain in Blizzard chat after combat ends"
    )
    assert(
      #deactivated == prevDeactivatedCount,
      "expected combat-carried draft edit box to remain open after combat ends"
    )
    assert(
      carriedDraftBox:GetText() == "typed during combat",
      "expected combat-carried draft text to remain unchanged after combat ends"
    )
    assert(
      carriedDraftBox:HasFocus() == true,
      "expected combat-carried draft focus to remain in Blizzard chat after combat ends"
    )
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
    pollFrame.scripts.OnUpdate(pollFrame)
    inCombat = false

    local prevSendTellCount = #sendTellCalls
    local prevDeactivatedCount = #deactivated
    local prevTimerCount = #timerCallbacks
    hookedFunctions["ChatFrame_SendTell"][1]("Arthas")

    assert(
      #sendTellCalls == prevSendTellCount,
      "expected direct hook to keep combat-carried draft in Blizzard chat after combat ends"
    )
    assert(#deactivated == prevDeactivatedCount, "expected direct hook not to close combat-carried draft edit box")
    assert(
      #timerCallbacks == prevTimerCount,
      "expected direct hook not to schedule deferred close for combat-carried draft"
    )
    assert(
      carriedDraftBox:GetText() == "typed during combat",
      "expected direct hook to preserve combat-carried draft text"
    )
    assert(carriedDraftBox:HasFocus() == true, "expected direct hook to preserve focus for combat-carried draft")
  end

  -- test_poller_routes_again_after_preserved_draft_cleared

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
    pollFrame.scripts.OnUpdate(pollFrame)
    inCombat = false

    resumedBox:SetText("")
    sendTellResult = true
    local prevSendTellCount = #sendTellCalls
    local prevDeactivatedCount = #deactivated
    pollFrame.scripts.OnUpdate(pollFrame)

    assert(
      #sendTellCalls == prevSendTellCount + 1 and sendTellCalls[#sendTellCalls] == "Arthas",
      "expected routing to resume once preserved combat draft is cleared"
    )
    assert(
      #deactivated == prevDeactivatedCount + 1 and deactivated[#deactivated] == resumedBox,
      "expected poller to close Blizzard chat edit box once preserved draft is cleared"
    )
    assert(resumedBox:HasFocus() == false, "expected cleared draft edit box to lose focus once normal routing resumes")
  end

  -- test_poller_tolerates_tainted_has_focus_during_lockdown

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
    taintedBox.HasFocus = function()
      error("attempt to perform boolean test on a secret boolean value (tainted by 'WhisperMessenger')")
    end
    _G.ChatFrame1EditBox = taintedBox

    local prevSendTellCount = #sendTellCalls
    local prevDeactivatedCount = #deactivated

    -- Combat path: findFocusedEditBox should gracefully return nil
    inCombat = true
    windowVisible = false
    local ok1, err1 = pcall(pollFrame.scripts.OnUpdate, pollFrame)
    assert(ok1, "expected combat poller to survive tainted HasFocus, got: " .. tostring(err1))

    -- Interception path: visible window during combat
    windowVisible = true
    local ok2, err2 = pcall(pollFrame.scripts.OnUpdate, pollFrame)
    assert(ok2, "expected interception poller to survive tainted HasFocus, got: " .. tostring(err2))

    assert(#sendTellCalls == prevSendTellCount, "expected no whisper routing when HasFocus is tainted")
    assert(#deactivated == prevDeactivatedCount, "expected no edit box close when HasFocus is tainted")

    inCombat = false
    windowVisible = false
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
  _G.ChatFrame_SendTell = savedGlobals.ChatFrame_SendTell
  _G.ChatFrame_ReplyTell = savedGlobals.ChatFrame_ReplyTell
  _G.ChatFrame_ReplyTell2 = savedGlobals.ChatFrame_ReplyTell2
end
