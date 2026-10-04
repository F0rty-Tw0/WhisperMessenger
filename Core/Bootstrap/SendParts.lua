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
  if type(payload.text) ~= "string" or #payload.text <= partBytesFor(payload.channel) then
    return nil
  end
  return MessageSplit.Split(payload.text, partBytesFor(payload.channel))
end

-- A unit the splitter cannot cut (a long link or texture escape) leaves a
-- part over the limit, which the game would reject.
local function hasOversizePart(parts, channel)
  for _, part in ipairs(parts) do
    if #part.text > partBytesFor(channel) then
      return true
    end
  end
  return false
end

-- transport: { sendWhisper(text) -> ok, dispatch(addonPayload),
-- canonical(text) -> the text fingerprints are taken over }.
-- A failed part stops the loop and drops every pending entry of the
-- message; a part over the limit sends nothing. Either way the caller then
-- records the whole text as failed.
function SendParts.Send(runtime, payload, parts, transport)
  if hasOversizePart(parts, payload.channel) then
    return false
  end
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
