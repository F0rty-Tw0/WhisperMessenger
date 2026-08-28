local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")
local Protocol = ns.MessageReactionProtocol or require("WhisperMessenger.Model.MessageReactionProtocol")
local SendHandler = ns.BootstrapSendHandler or require("WhisperMessenger.Core.Bootstrap.SendHandler")

local ReactionHandler = {}

local function localActorName(runtime)
  if type(runtime.localPlayerName) == "string" and runtime.localPlayerName ~= "" then
    return runtime.localPlayerName
  end
  if type(_G.UnitName) == "function" then
    local ok, name = pcall(_G.UnitName, "player")
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end
  return "You"
end

function ReactionHandler.HandleReact(runtime, selectedContact, message, reactionKey, refreshWindow, groupSendPolicy)
  if
    type(runtime) ~= "table"
    or type(selectedContact) ~= "table"
    or not MessageReactions.IsEligible(message, selectedContact.channel)
    or not Protocol.IsReactionKey(reactionKey)
  then
    return false
  end

  if type(runtime.isCompetitiveContent) == "function" and runtime.isCompetitiveContent() then
    return false
  end

  local operation = "set"
  local visibleReaction = MessageReactions.VisibleReaction(message)
  if type(visibleReaction) == "table" and visibleReaction.key == reactionKey then
    operation = "remove"
  end
  local actorName = localActorName(runtime)
  local pendingToken = MessageReactions.NewPendingToken(runtime)
  local refresh = refreshWindow or function() end
  if selectedContact.channel ~= "WOW" and selectedContact.channel ~= "BN" then
    if type(groupSendPolicy) ~= "table" or type(groupSendPolicy.sendReaction) ~= "function" then
      return false
    end
    local accepted, reactionControl =
      groupSendPolicy.sendReaction(selectedContact.conversation or selectedContact, message, reactionKey, operation, actorName, pendingToken)
    if accepted then
      if type(reactionControl) == "table" and reactionControl.confirmed ~= true then
        MessageReactions.BeginPending(message, pendingToken, operation, reactionKey, actorName, refresh)
      end
      refresh()
    end
    return accepted
  end

  local fallback = Protocol.BuildFallback(reactionKey, operation, message.text or "")
  if fallback == nil then
    return false
  end
  local reactionControl = {
    actorName = actorName,
    sourceText = message.text or "",
    pendingToken = pendingToken,
    operation = {
      type = "reaction",
      operation = operation,
      key = reactionKey,
      wireId = message.wireId,
      sourceFingerprint = Protocol.Fingerprint(message.text or ""),
      fallbackFingerprint = Protocol.Fingerprint(fallback),
    },
  }

  local accepted = SendHandler.HandleSend(runtime, {
    conversationKey = selectedContact.conversationKey,
    target = selectedContact.displayName,
    displayName = selectedContact.displayName,
    battleTag = selectedContact.battleTag,
    channel = selectedContact.channel,
    bnetAccountID = selectedContact.bnetAccountID,
    conversationID = selectedContact.conversationID,
    guid = selectedContact.guid,
    gameAccountName = selectedContact.gameAccountName,
    text = fallback,
    reactionControl = reactionControl,
  }, refresh)
  if accepted then
    if reactionControl.confirmed ~= true then
      MessageReactions.BeginPending(message, pendingToken, operation, reactionKey, actorName, refresh)
    end
    refresh()
  end
  return accepted
end

ns.BootstrapReactionHandler = ReactionHandler
return ReactionHandler
