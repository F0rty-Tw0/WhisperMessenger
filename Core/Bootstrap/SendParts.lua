local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Router = ns.EventRouter or require("WhisperMessenger.Core.EventRouter")
local PendingOutgoing = ns.EventRouterPendingOutgoing or require("WhisperMessenger.Core.EventRouter.PendingOutgoing")
local MessageSplit = ns.MessageSplit or require("WhisperMessenger.Util.MessageSplit")
local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")
local MessageParts = ns.MessageParts or require("WhisperMessenger.Model.MessageParts")
local MessageReactionProtocol = ns.MessageReactionProtocol or require("WhisperMessenger.Model.MessageReactionProtocol")

-- Sends a whisper too long for one chat message as several whispers that
-- share one wire id. The composer caps typed text at MAX_PARTS parts, but
-- the wire text can grow (quest-link rewrite); every part still goes out.
local SendParts = {}

local function partBytesFor(channel)
  if channel == "BN" then
    return TextLimits.BNET_PART_BYTES
  end
  return TextLimits.MESSAGE_MAX_BYTES
end

-- The parts of payload.text, or nil when it fits one whisper.
function SendParts.Split(payload)
  if type(payload.text) ~= "string" then
    return nil
  end
  local parts = MessageSplit.Split(payload.text, partBytesFor(payload.channel))
  if #parts < 2 then
    return nil
  end
  return parts
end

-- transport: { sendWhisper(text) -> ok, dispatch(addonPayload),
-- canonical(text) -> the text fingerprints are taken over }.
-- A failed part stops the loop and drops every pending entry of the
-- message; the caller then records the whole text as failed.
function SendParts.Send(runtime, payload, parts, transport)
  local wireId = payload.wireId or MessageReactionProtocol.NewWireId(runtime, runtime.now and runtime.now() or 0)
  payload.wireId = wireId
  local transportParts = {}
  for index, part in ipairs(parts) do
    Router.RecordPendingSend(runtime, payload, part.text, {
      wireId = wireId,
      replyTo = payload.replyTo,
      partIndex = index,
      partCount = #parts,
      join = part.join,
      fullText = payload.text,
    })
    if not transport.sendWhisper(part.text) then
      PendingOutgoing.DropWire(runtime, wireId)
      return false
    end
    transportParts[index] = { text = transport.canonical(part.text), join = part.join }
  end
  transport.dispatch(MessageReactionProtocol.EncodeIdentity(wireId, transportParts[1].text))
  transport.dispatch(MessageParts.EncodeManifest(wireId, transportParts))
  return true
end

ns.BootstrapSendParts = SendParts
return SendParts
