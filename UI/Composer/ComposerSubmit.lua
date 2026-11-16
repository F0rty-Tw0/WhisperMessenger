local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SlashCommand = ns.ComposerSlashCommand or require("WhisperMessenger.UI.Composer.SlashCommand")

-- Sending what the player typed: a slash command runs through the chat box,
-- anything else goes out as a whisper, and the composer clears on success.
local ComposerSubmit = {}

-- parts: input, replies, limit, sendFocus, selectedContact, onSend,
-- onDraftChanged, isDisabled(), afterClear() (runs once the input is cleared,
-- since SetText alone may not fire OnTextChanged).
function ComposerSubmit.Create(parts)
  local input, selectedContact = parts.input, parts.selectedContact

  local function clearAfterSend()
    parts.replies.clear()
    input:SetText("")
    parts.limit.remember()
    if parts.onDraftChanged then
      parts.onDraftChanged(selectedContact.conversationKey, "")
    end
    parts.sendFocus.afterSend()
    parts.afterClear()
  end

  return function()
    if parts.isDisabled() then
      return
    end

    local text = input.GetText and input:GetText() or input.text
    if text == nil or text == "" then
      return
    end

    -- A slash command never goes out as a whisper; with no chat box to run it, the text stays put.
    local command = SlashCommand.Parse(text)
    if command ~= nil then
      if SlashCommand.Run(command) then
        clearAfterSend()
      end
      return
    end

    local accepted = parts.onSend({
      conversationKey = selectedContact.conversationKey,
      target = selectedContact.displayName,
      displayName = selectedContact.displayName,
      channel = selectedContact.channel,
      bnetAccountID = selectedContact.bnetAccountID,
      conversationID = selectedContact.conversationID,
      guid = selectedContact.guid,
      gameAccountName = selectedContact.gameAccountName,
      text = text,
      replyTo = parts.replies.current(),
    })

    if accepted ~= false then
      clearAfterSend()
    end
  end
end

ns.ComposerSubmit = ComposerSubmit
return ComposerSubmit
