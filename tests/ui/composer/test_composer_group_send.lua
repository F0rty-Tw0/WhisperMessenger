-- Tests for group-channel composer send path (Stage 6).
-- The Composer's onSend callback receives the payload; these tests verify that
-- the payload contains the correct channel field so the caller can route it
-- through ChatGateway.Send, and that the composer clears its input on success.
-- They also verify the disabled state when CanSend returns false.

local Composer = require("WhisperMessenger.UI.Composer")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local ChatGateway = require("WhisperMessenger.Transport.ChatGateway")
local FakeUI = require("tests.helpers.fake_ui")

local function makeGroupComposer(channel, conversationKey, extraContact, onSend)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 50)
  local selectedContact = {
    conversationKey = conversationKey or ("me::" .. channel .. "::1"),
    displayName = channel .. "-chat",
    channel = channel,
  }
  if extraContact then
    for k, v in pairs(extraContact) do
      selectedContact[k] = v
    end
  end
  local composer = Composer.Create(factory, parent, selectedContact, onSend or function() end, function() end, nil)
  return composer, selectedContact
end

return function()
  -- ---------------------------------------------------------------------------
  -- 1. PARTY conversation: Enter fires onSend with PARTY channel
  -- ---------------------------------------------------------------------------
  do
    local sent = {}
    local composer = makeGroupComposer(ChannelType.PARTY, "me::PARTY::1", nil, function(payload)
      table.insert(sent, payload)
    end)

    composer.input:SetText("Let's go")
    composer.input.scripts.OnEnterPressed(composer.input)

    assert(#sent == 1, "expected one send for PARTY, got " .. tostring(#sent))
    assert(sent[1].channel == ChannelType.PARTY, "expected PARTY channel in payload")
    assert(sent[1].text == "Let's go", "expected text forwarded")
    assert(composer.input.text == "", "expected input cleared after send")
  end

  -- ---------------------------------------------------------------------------
  -- 2. INSTANCE_CHAT conversation: Enter fires onSend with INSTANCE_CHAT channel
  -- ---------------------------------------------------------------------------
  do
    local sent = {}
    local composer = makeGroupComposer(ChannelType.INSTANCE_CHAT, "me::INSTANCE_CHAT::1", nil, function(payload)
      table.insert(sent, payload)
    end)

    composer.input:SetText("Stack on boss")
    composer.input.scripts.OnEnterPressed(composer.input)

    assert(#sent == 1, "expected one send for INSTANCE_CHAT, got " .. tostring(#sent))
    assert(sent[1].channel == ChannelType.INSTANCE_CHAT, "expected INSTANCE_CHAT channel in payload")
    assert(sent[1].text == "Stack on boss", "expected text forwarded")
    assert(composer.input.text == "", "expected input cleared after send")
  end

  -- ---------------------------------------------------------------------------
  -- 3. BN_CONVERSATION: onSend receives conversationID
  -- ---------------------------------------------------------------------------
  do
    local sent = {}
    local composer, _ = makeGroupComposer(ChannelType.BN_CONVERSATION, "me::BN_CONVERSATION::7", { conversationID = 7 }, function(payload)
      table.insert(sent, payload)
    end)

    composer.input:SetText("Hi group")
    composer.input.scripts.OnEnterPressed(composer.input)

    assert(#sent == 1, "expected one send for BN_CONVERSATION, got " .. tostring(#sent))
    assert(sent[1].channel == ChannelType.BN_CONVERSATION, "expected BN_CONVERSATION channel in payload")
    assert(sent[1].conversationID == 7, "expected conversationID forwarded")
    assert(sent[1].text == "Hi group", "expected text forwarded")
  end

  -- ---------------------------------------------------------------------------
  -- 4. WHISPER regression: onSend still fires with WHISPER channel
  -- ---------------------------------------------------------------------------
  do
    local sent = {}
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "parent", nil)
    parent:SetSize(600, 50)
    local selectedContact = {
      conversationKey = "me::WHISPER::arthas-area52",
      displayName = "Arthas-Area52",
      channel = ChannelType.WHISPER,
      target = "Arthas-Area52",
    }
    local composer = Composer.Create(factory, parent, selectedContact, function(payload)
      table.insert(sent, payload)
    end, function() end, nil)

    composer.input:SetText("Hey there")
    composer.input.scripts.OnEnterPressed(composer.input)

    assert(#sent == 1, "expected one send for WHISPER, got " .. tostring(#sent))
    assert(sent[1].channel == ChannelType.WHISPER, "expected WHISPER channel in payload")
    assert(sent[1].target == "Arthas-Area52", "expected target forwarded")
    assert(sent[1].text == "Hey there", "expected text forwarded")
  end

  -- ---------------------------------------------------------------------------
  -- 5. Disabled composer: onSend is NOT called when send is disabled
  -- ---------------------------------------------------------------------------
  do
    local sent = {}
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "parent", nil)
    parent:SetSize(600, 50)
    -- Pass nil as selectedContact to disable the composer from the start
    local composer = Composer.Create(factory, parent, nil, function(payload)
      table.insert(sent, payload)
    end, function() end, nil)

    composer.input:SetText("should not send")
    composer.input.scripts.OnEnterPressed(composer.input)

    assert(#sent == 0, "expected no send when composer is disabled, got " .. tostring(#sent))
  end

  -- ---------------------------------------------------------------------------
  -- 6. setEnabled(false) disables the composer; setEnabled(true) re-enables it
  -- ---------------------------------------------------------------------------
  do
    local sent = {}
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "parent", nil)
    parent:SetSize(600, 50)
    local selectedContact = {
      conversationKey = "me::PARTY::1",
      displayName = "PARTY-chat",
      channel = ChannelType.PARTY,
    }
    local composer = Composer.Create(factory, parent, selectedContact, function(payload)
      table.insert(sent, payload)
    end, function() end, nil)

    -- Disable via setEnabled
    composer.setEnabled(false)
    composer.input:SetText("blocked")
    composer.input.scripts.OnEnterPressed(composer.input)
    assert(#sent == 0, "expected no send when setEnabled(false), got " .. tostring(#sent))

    -- Re-enable
    composer.setEnabled(true)
    composer.input:SetText("now works")
    composer.input.scripts.OnEnterPressed(composer.input)
    assert(#sent == 1, "expected one send after setEnabled(true), got " .. tostring(#sent))
    assert(sent[1].text == "now works", "expected correct text after re-enable")
  end

  -- ---------------------------------------------------------------------------
  -- 7. onSend does NOT call Store.AppendOutgoing for group channels
  --    (verified by ensuring no AppendOutgoing key on the payload-receiver side;
  --     the test simply confirms the payload carries channel info and the
  --     caller – not the composer – is responsible for routing)
  -- ---------------------------------------------------------------------------
  do
    local sent = {}
    local appendOutgoingCalled = false
    local composer = makeGroupComposer(ChannelType.PARTY, "me::PARTY::1", nil, function(payload)
      -- Simulate the caller: route via ChatGateway, NOT Store.AppendOutgoing
      table.insert(sent, payload)
      -- If a caller accidentally called AppendOutgoing it would set this flag
      -- via a side-effect; we simply assert the payload does not have a
      -- pre-appended message in it (no "messages" field inserted by composer)
      if payload.messages ~= nil then
        appendOutgoingCalled = true
      end
    end)

    composer.input:SetText("test no append")
    composer.input.scripts.OnEnterPressed(composer.input)

    assert(#sent == 1, "expected send to be routed")
    assert(appendOutgoingCalled == false, "composer must not pre-append messages for group channels")
  end

  -- ---------------------------------------------------------------------------
  -- 8. pcall integration: ChatGateway.Send errors do not crash when wrapped
  --    (COMMUNITY active conversation — gateway will error, pcall must catch it)
  -- ---------------------------------------------------------------------------
  do
    local errors = {}
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "parent", nil)
    parent:SetSize(600, 50)
    local selectedContact = {
      conversationKey = "me::COMMUNITY::1",
      displayName = "Community-chat",
      channel = ChannelType.COMMUNITY,
    }
    local api = { SendChatMessage = function() end, SendConversationMessage = function() end }
    local composer = Composer.Create(factory, parent, selectedContact, function(payload)
      -- Simulate the WindowRuntime onSend handler: pcall ChatGateway.Send
      local ok, err = pcall(ChatGateway.Send, api, payload, payload.text)
      if not ok then
        table.insert(errors, err)
      end
    end, function() end, nil)

    composer.input:SetText("community msg")
    composer.input.scripts.OnEnterPressed(composer.input)

    -- COMMUNITY errors in ChatGateway.Send; pcall must catch it without crashing
    assert(#errors == 1, "expected one caught error for COMMUNITY send, got " .. tostring(#errors))
    assert(type(errors[1]) == "string" and errors[1]:find("receive%-only") ~= nil, "expected 'receive-only' error, got: " .. tostring(errors[1]))
  end

  print("PASS: test_composer_group_send")
end
