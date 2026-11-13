local Poller = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.Poller")
local Flavor = require("tests.helpers.flavor")

local function makeEditBox()
  local box = { text = "", scripts = {}, attributes = { chatType = "SAY", stickyType = "SAY" } }
  function box:GetText()
    return self.text
  end
  function box:SetText(text)
    self.text = text
  end
  function box:GetAttribute(key)
    return self.attributes[key]
  end
  function box:SetAttribute(key, value)
    self.attributes[key] = value
  end
  function box:HookScript(scriptName, handler)
    self.scripts[scriptName] = handler
  end
  function box:Hide() end
  return box
end

-- Installs the poller on one chat edit box and returns a typer that sets the
-- box text as user input, the list of names routed to onSendTell, and the
-- texts carried over into the composer.
local function installPoller(replyOpens)
  local editBox = makeEditBox()
  local sendTellCalls = {}
  local composerTexts = {}
  local replyCalls = {}
  local runtime = {
    setComposerText = function(text)
      table.insert(composerTexts, text)
    end,
  }
  local hooks = {
    onSendTell = function(target)
      table.insert(sendTellCalls, target)
      return true
    end,
    onReplyTell = function()
      table.insert(replyCalls, true)
      return replyOpens ~= false
    end,
  }
  local deps = {
    isSuspended = function()
      return false
    end,
    getNumChatWindows = function()
      return 1
    end,
    getEditBox = function()
      return editBox
    end,
    deactivateChat = function() end,
  }
  Poller.Install(runtime, hooks, deps)

  local function typeText(text)
    editBox.text = text
    editBox.scripts.OnTextChanged(editBox, true)
  end
  return typeText, sendTellCalls, composerTexts, replyCalls, editBox
end

return function()
  -- test_forever_slash_whisper_waits_for_last_name
  -- WoW: Forever characters have two names ("John Doe"). The space after the
  -- first name is part of the target, so `/w John ` must stay in default chat.
  Flavor.With(false, true, function()
    local typeText, sendTellCalls = installPoller()
    typeText("/w John ")
    typeText("/w John D")
    assert(#sendTellCalls == 0, "expected '/w John ' not to route on Forever, got " .. tostring(sendTellCalls[1]))
  end)

  -- test_forever_slash_whisper_routes_full_two_part_name
  Flavor.With(false, true, function()
    local typeText, sendTellCalls = installPoller()
    typeText("/w John Doe ")
    assert(sendTellCalls[1] == "John Doe", "expected full Forever name routed, got " .. tostring(sendTellCalls[1]))
  end)

  -- test_forever_slash_whisper_carries_message_into_composer
  Flavor.With(false, true, function()
    local typeText, _sendTellCalls, composerTexts = installPoller()
    typeText("/w John Doe hi there")
    assert(composerTexts[1] == "hi there", "expected message carried into composer, got " .. tostring(composerTexts[1]))
  end)

  -- test_forever_slash_whisper_collapses_spaces_between_names
  -- "John  Doe" must reach the same chat as "John Doe", not a duplicate.
  Flavor.With(false, true, function()
    local typeText, sendTellCalls = installPoller()
    typeText("/w John  Doe ")
    assert(sendTellCalls[1] == "John Doe", "expected spaces between names collapsed, got " .. tostring(sendTellCalls[1]))
  end)

  -- test_forever_slash_whisper_hash_in_message_keeps_two_part_name
  Flavor.With(false, true, function()
    local typeText, sendTellCalls = installPoller()
    typeText("/w John Doe #1 ")
    assert(sendTellCalls[1] == "John Doe", "expected '#' in the message not to shorten the name, got " .. tostring(sendTellCalls[1]))
  end)

  -- test_forever_slash_whisper_keeps_battletag_one_word
  -- A BattleTag ("Name#1234") is a whole target on its own; the next word is
  -- the message, not a last name.
  Flavor.With(false, true, function()
    local typeText, sendTellCalls = installPoller()
    typeText("/w Artiom#1234 ")
    assert(sendTellCalls[1] == "Artiom#1234", "expected BattleTag routed alone on Forever, got " .. tostring(sendTellCalls[1]))
  end)

  -- test_retail_slash_whisper_routes_after_first_space
  Flavor.With(true, false, function()
    local typeText, sendTellCalls = installPoller()
    typeText("/w Thrall ")
    assert(sendTellCalls[1] == "Thrall", "expected one-word name routed on Retail, got " .. tostring(sendTellCalls[1]))
  end)

  -- test_classic_slash_whisper_routes_after_first_space
  Flavor.With(false, false, function()
    local typeText, sendTellCalls = installPoller()
    typeText("/w Thrall ")
    assert(sendTellCalls[1] == "Thrall", "expected one-word name routed on Classic, got " .. tostring(sendTellCalls[1]))
  end)

  -- test_slash_reply_opens_messenger_after_space
  do
    local typeText, _sendTellCalls, _composerTexts, replyCalls, editBox = installPoller()
    typeText("/r ")
    assert(#replyCalls == 1, "expected '/r ' to open the reply chat, got " .. #replyCalls .. " calls")
    assert(editBox.text == "", "expected the chat box cleared after routing, got " .. tostring(editBox.text))
  end

  -- test_slash_reply_carries_message_into_composer
  do
    local typeText, _sendTellCalls, composerTexts = installPoller()
    typeText("/reply hi there")
    assert(composerTexts[1] == "hi there", "expected message carried into composer, got " .. tostring(composerTexts[1]))
  end

  -- test_slash_reply_waits_for_space
  -- "/r" may still become "/raid"; only the space makes it a reply.
  do
    local typeText, _sendTellCalls, _composerTexts, replyCalls = installPoller()
    typeText("/r")
    typeText("/ra ")
    assert(#replyCalls == 0, "expected no reply before '/r ' is complete, got " .. #replyCalls .. " calls")
  end

  -- test_slash_reply_without_target_stays_in_chat
  do
    local typeText, _sendTellCalls, _composerTexts, _replyCalls, editBox = installPoller(false)
    typeText("/r ")
    assert(editBox.text == "/r ", "expected chat box untouched when nobody to reply to, got " .. tostring(editBox.text))
  end

  -- test_slash_reply_accepts_localized_command
  do
    local savedReply1, savedReply2 = rawget(_G, "SLASH_REPLY1"), rawget(_G, "SLASH_REPLY2")
    rawset(_G, "SLASH_REPLY1", "/r")
    rawset(_G, "SLASH_REPLY2", "/ANTWORTEN")
    local typeText, _sendTellCalls, _composerTexts, replyCalls = installPoller()
    local ok, err = pcall(function()
      typeText("/antworten ")
      assert(#replyCalls == 1, "expected a localized reply command to open the reply chat, got " .. #replyCalls .. " calls")
    end)
    rawset(_G, "SLASH_REPLY1", savedReply1)
    rawset(_G, "SLASH_REPLY2", savedReply2)
    assert(ok, err)
  end

  -- test_focus_with_stale_whisper_target_routes
  -- An empty box still holding a whisper target routes to that player when it
  -- gains focus.
  do
    local _typeText, sendTellCalls, _composerTexts, _replyCalls, editBox = installPoller()
    editBox.attributes.chatType = "WHISPER"
    editBox.attributes.tellTarget = "Thrall"
    editBox.scripts.OnEditFocusGained(editBox)
    assert(sendTellCalls[1] == "Thrall", "expected a focused whisper box to route, got " .. tostring(sendTellCalls[1]))
  end
end
