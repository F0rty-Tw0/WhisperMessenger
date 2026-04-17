local FakeUI = require("tests.helpers.fake_ui")
local AutoOpenCoordinator = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator")

return function()
  -- test_deferred_close_bails_when_competitive_content_activates

  -- C_Timer.After(0, cb) schedules on the next tick. If the scheduling
  -- frame fired BEFORE ENCOUNTER_START but the callback runs AFTER, any
  -- edit-box writes in the callback now execute inside a lockdown context
  -- and taint Blizzard's secure chat path (ChatEdit_SetLastTellTarget,
  -- UpdateHeader). The callback must re-check runtime.isCompetitiveContent
  -- at fire time and bail before touching the edit box.
  local factory = FakeUI.NewFactory()
  local savedCreateFrame = _G.CreateFrame
  local savedCTimer = _G.C_Timer
  local savedDeactivate = _G.ChatEdit_DeactivateChat
  local savedInCombatLockdown = _G.InCombatLockdown
  local savedNumChatWindows = _G.NUM_CHAT_WINDOWS
  local savedHooksecurefunc = _G.hooksecurefunc
  local savedSendTell = _G.ChatFrame_SendTell
  local savedWmSuspended = _G._wmSuspended

  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.NUM_CHAT_WINDOWS = 1
  _G._wmSuspended = false
  rawset(_G, "InCombatLockdown", function()
    return false
  end)

  local timerQueue = {}
  _G.C_Timer = {
    After = function(_delay, cb)
      table.insert(timerQueue, cb)
    end,
  }

  local deactivateCalls = 0
  rawset(_G, "ChatEdit_DeactivateChat", function()
    deactivateCalls = deactivateCalls + 1
  end)

  rawset(_G, "CreateFrame", function(...)
    return factory.CreateFrame(...)
  end)

  local hookHandlers = {}
  rawset(_G, "hooksecurefunc", function(name, fn)
    hookHandlers[name] = fn
  end)
  rawset(_G, "ChatFrame_SendTell", function() end)

  local editBox = factory.CreateFrame("EditBox", "ChatFrame1EditBox", _G.UIParent)
  editBox:SetText("hi")
  editBox.chatType = "WHISPER"
  editBox.tellTarget = "Arthas"
  editBox.GetAttribute = function(self, key)
    return rawget(self, key)
  end
  editBox.SetAttribute = function(self, key, value)
    rawset(self, key, value)
  end
  _G.ChatFrame1EditBox = editBox
  editBox:SetFocus()

  local competitiveActive = false
  local runtime = {
    lastIncomingWhisperKey = "me::WOW::arthas",
    activeConversationKey = nil,
    accountState = { settings = { autoOpenIncoming = true, autoOpenOutgoing = true } },
    isCompetitiveContent = function()
      return competitiveActive
    end,
    ensureWindow = function() end,
    setWindowVisible = function() end,
  }

  local opened = false
  local windowRuntime = {
    selectConversation = function()
      opened = true
    end,
    isWindowVisible = function()
      return true
    end,
  }

  local controller = AutoOpenCoordinator.Attach({
    runtime = runtime,
    accountState = runtime.accountState,
    windowRuntime = windowRuntime,
    AutoOpenHooks = {
      Create = function()
        return {
          onIncomingWhisper = function()
            return true
          end,
          onOutgoingWhisper = function()
            return true
          end,
          onSendTell = function()
            opened = true
            return true
          end,
          onReplyTell = function()
            opened = true
            return true
          end,
        }
      end,
    },
  })

  controller.installPoller()

  -- Simulate ChatFrame_SendTell firing while outside competitive content
  assert(type(hookHandlers.ChatFrame_SendTell) == "function", "SendTell hook should be installed")
  hookHandlers.ChatFrame_SendTell("Arthas")

  assert(opened == true, "expected hook to open messenger for explicit whisper")
  assert(#timerQueue == 1, "expected deferred editbox-close timer to be queued, got " .. #timerQueue)

  -- Now simulate ENCOUNTER_START firing before the deferred callback runs
  competitiveActive = true
  deactivateCalls = 0

  -- Drain the deferred callback
  timerQueue[1]()

  assert(
    deactivateCalls == 0,
    "deferred close must bail when competitive content activates between schedule and fire; got "
      .. deactivateCalls
      .. " ChatEdit_DeactivateChat calls"
  )

  _G.CreateFrame = savedCreateFrame
  _G.C_Timer = savedCTimer
  rawset(_G, "ChatEdit_DeactivateChat", savedDeactivate)
  rawset(_G, "InCombatLockdown", savedInCombatLockdown)
  _G.NUM_CHAT_WINDOWS = savedNumChatWindows
  rawset(_G, "hooksecurefunc", savedHooksecurefunc)
  rawset(_G, "ChatFrame_SendTell", savedSendTell)
  _G._wmSuspended = savedWmSuspended
  _G.ChatFrame1EditBox = nil
end
