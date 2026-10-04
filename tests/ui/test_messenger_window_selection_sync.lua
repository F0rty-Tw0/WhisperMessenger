local SelectionSync = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SelectionSync")

local function recordingComposer()
  local calls = {}
  return {
    calls = calls,
    setMaxBytes = function(channel)
      table.insert(calls, "cap:" .. tostring(channel))
    end,
    loadDraft = function(text)
      table.insert(calls, "draft:" .. tostring(text))
    end,
  }
end

return function()
  -- test_cap_is_set_before_the_draft_loads
  do
    local target, composer = {}, recordingComposer()
    local drafts = { ["me::WOW::arthas"] = "long whisper draft" }
    SelectionSync.SyncComposerSelectedContact(target, { conversationKey = "me::WOW::arthas", channel = "WOW" }, composer, function(key)
      return drafts[key]
    end)
    assert(composer.calls[1] == "cap:WOW", "cap set first, got " .. tostring(composer.calls[1]))
    assert(composer.calls[2] == "draft:long whisper draft", "then the draft loads")
  end

  -- test_group_to_whisper_to_group_switches_the_cap
  do
    local target, composer = {}, recordingComposer()
    local function getDraft()
      return nil
    end
    SelectionSync.SyncComposerSelectedContact(target, { conversationKey = "me::PARTY::party", channel = "PARTY" }, composer, getDraft)
    SelectionSync.SyncComposerSelectedContact(target, { conversationKey = "me::WOW::arthas", channel = "WOW" }, composer, getDraft)
    SelectionSync.SyncComposerSelectedContact(target, { conversationKey = "me::PARTY::party", channel = "PARTY" }, composer, getDraft)
    assert(composer.calls[1] == "cap:PARTY" and composer.calls[3] == "cap:WOW" and composer.calls[5] == "cap:PARTY", "cap follows each conversation")
  end

  -- test_same_conversation_leaves_composer_alone
  do
    local target, composer = { conversationKey = "me::WOW::arthas" }, recordingComposer()
    SelectionSync.SyncComposerSelectedContact(target, { conversationKey = "me::WOW::arthas", channel = "WOW" }, composer, nil)
    assert(#composer.calls == 0, "no cap or draft change for the same conversation")
  end
end
