local Store = require("WhisperMessenger.Model.ConversationStore")
local ReactionHandler = require("WhisperMessenger.Core.Bootstrap.ReactionHandler")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")

local function newStore()
  return Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 })
end

return function()
  local savedClassic = FlavorCompat.isClassic
  local savedUnitName = _G.UnitName
  local savedInCombatLockdown = _G.InCombatLockdown
  FlavorCompat.isClassic = false
  rawset(_G, "UnitName", function()
    return "Artio"
  end)
  rawset(_G, "InCombatLockdown", function()
    return false
  end)

  local expandingSource = string.rep("[Quest Name (123)] ", 11)
  assert(#expandingSource < 255, "fixture source should fit one whisper before link expansion")

  -- Retail character path rewrites plain quest refs before dispatch but must remain capped.
  do
    local dispatched
    local runtime = {
      localProfileId = "me",
      store = newStore(),
      pendingOutgoing = {},
      sendStatusByConversation = {},
      availabilityByGUID = {},
      now = function()
        return 100
      end,
      chatApi = {
        SendChatMessage = function(text)
          dispatched = text
        end,
        RegisterAddonMessagePrefix = function() end,
        SendAddonMessage = function() end,
      },
      bnetApi = {},
    }
    local key = "wow::WOW::arthas-area52"
    local target = { kind = "user", direction = "in", text = expandingSource, wireId = "retailtarget", sentAt = 90 }
    runtime.store.conversations[key] = { conversationKey = key, messages = { target }, unreadCount = 0 }
    local accepted = ReactionHandler.HandleReact(runtime, {
      conversationKey = key,
      displayName = "Arthas-Area52",
      guid = "Player-1",
      channel = "WOW",
    }, target, "heart", function() end)
    assert(accepted == true and type(dispatched) == "string", "Retail reaction fallback should dispatch")
    assert(#dispatched <= 255, "Retail dispatched fallback should remain within 255 bytes after quest-link expansion, got " .. tostring(#dispatched))
  end

  -- Battle.net also uses Rewrite and must cap the final dispatched text.
  do
    local dispatched
    local accountInfo = {
      bnetAccountID = 77,
      battleTag = "Jaina#1234",
      gameAccountInfo = { characterName = "Jaina", realmName = "Proudmoore" },
    }
    local runtime = {
      localProfileId = "me",
      store = newStore(),
      pendingOutgoing = {},
      sendStatusByConversation = {},
      availabilityByGUID = {},
      now = function()
        return 200
      end,
      chatApi = { RegisterAddonMessagePrefix = function() end },
      bnetApi = {
        SendWhisper = function(_, text)
          dispatched = text
        end,
        SendGameData = function() end,
        GetAccountInfoByID = function()
          return accountInfo
        end,
        GetNumFriends = function()
          return 1
        end,
        GetFriendAccountInfo = function()
          return accountInfo
        end,
      },
    }
    local key = "bnet::BN::jaina#1234"
    local target = { kind = "user", direction = "in", text = expandingSource, wireId = "bntarget", sentAt = 190 }
    runtime.store.conversations[key] = {
      conversationKey = key,
      channel = "BN",
      battleTag = "Jaina#1234",
      bnetAccountID = 77,
      messages = { target },
      unreadCount = 0,
    }
    local accepted = ReactionHandler.HandleReact(runtime, {
      conversationKey = key,
      displayName = "Jaina#1234",
      battleTag = "Jaina#1234",
      channel = "BN",
      bnetAccountID = 77,
    }, target, "question", function() end)
    assert(accepted == true and type(dispatched) == "string", "BN reaction fallback should dispatch")
    assert(#dispatched <= 255, "BN dispatched fallback should remain within 255 bytes after quest-link expansion, got " .. tostring(#dispatched))
  end

  FlavorCompat.isClassic = savedClassic
  rawset(_G, "UnitName", savedUnitName)
  rawset(_G, "InCombatLockdown", savedInCombatLockdown)
end
